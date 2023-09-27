module conversion::shapeConversion::combineOverlap

import util::Maybe;
import List;
import Map;
import Set;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::shapeConversion::defineSequence;
import conversion::util::meta::RegexSources;
import conversion::util::meta::extractSources;
import conversion::util::meta::LabelTools;
import conversion::util::meta::applyScopesAndSources;
import conversion::util::makeLookahead;
import regex::PSNFATypes;
import regex::RegexTypes;
import regex::regexToPSNFA;
import regex::RegexCache;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::RegexTransformations;
import regex::PSNFASimplification;
import Warning;
import Scope;
import Visualize;

@doc {
    Combines productions that start with the same prefix, e.g.:
    ```
    A -> X A Y B Z A
    A -> X D Z A
    ```
    =>
    ```
    A -> X unionRec(A|convSeq(Y B)|D) Z A
    ```
}
tuple[
    list[Warning] warnings,
    set[ConvProd] prods,
    ConversionGrammar grammar
] combineOverlap(set[ConvProd] prods, ConversionGrammar grammar) {
    map[NFA[State], set[ConvProd]] indexed = ();
    set[ConvProd] out = {};

    // Index all productions into groups with overlap
    for(p:convProd(_, parts) <- prods){
        if([regexp(r), *_] := parts) {
            nfa = regexToPSNFA(r);
            if(nfa in indexed) {
                indexed[nfa] += p;
            } else {
                overlapNfas = {nfa2 | nfa2 <- indexed, overlaps(nfa, nfa2)};
                if({} := overlapNfas) {
                    indexed[nfa] = {p};
                } else {
                    combinedProds = {p};
                    for(nfa2 <- overlapNfas) {
                        combinedProds += indexed[nfa2];
                        nfa = unionPSNFA(nfa, nfa2);
                        indexed = delete(indexed, nfa2);
                    }
                    indexed[nfa] = combinedProds;
                }
            } 
        } else {
            out += p; // Empty prods
        }
    }

    // Add all productions to output
    list[Warning] warnings = [];
    for(group <- indexed<1>) {
        if({p} := group) {
            out += p;
        } else {
            <nWarnings, newProd, grammar> = combineProductions(group, grammar);
            warnings += nWarnings;
            out += newProd;
        }
    }

    return <warnings, out, grammar>;
}

alias SourcedSequence = tuple[list[ConvSymbol], ConvProd];

@doc {
    Creates a production that represents the union of the given set of productions, E.g.:
    ```
    A -> X A Y B Z A
    A -> X D Z A
    ```
    =>
    ```
    A -> X unionRec(A|convSeq(Y B)|D) Z A
    ```
}
tuple[
    list[Warning] warnings,
    ConvProd prod,
    ConversionGrammar grammar  
] combineProductions(set[ConvProd] prods, ConversionGrammar grammar) {
    <warnings, combinedParts, grammar> = combineSequences({<parts, p> | p:convProd(_, parts) <- prods}, grammar);

    lDef = getOneFrom(prods).def;
    combinedLabelDef = combineLabels(lDef, {lDef2 | convProd(lDef2, _) <- prods});
    outProd = convProd(combinedLabelDef, combinedParts);
    
    return <warnings, outProd, grammar>;
}
    
tuple[
    list[Warning] warnings,
    list[ConvSymbol] sequence,
    ConversionGrammar grammar  
] combineSequences(set[SourcedSequence] sequences, ConversionGrammar grammar) {
    list[Warning] warnings = [];
    if({<baseParts:[regexp(r), *_], baseProd>, *restSequences} := sequences) {        
        // Make sure the first regex is always included in the prefix, even if the regexes only overlap but aren't equivalent
        list[ConvSymbol] prefix = [];
        for(<[regexp(r2), *_], p> <- restSequences) {
            if(isSubset(r2, r)) {
                r = addRegexSources(r, extractAllRegexSources(r2));
            } else if(isSubset(r, r2)) {
                r = addRegexSources(r2, extractAllRegexSources(r));
            } else {
                r = getCachedRegex(alternation(r, r2));
            }
        }
        prefix += regexp(r);

        // Find a common suffix
        <suffixWarnings, reversedSuffix> = findCommon(
            Maybe[ConvSymbol](list[ConvSymbol] parts, int index) {
                index = size(parts) - index - 1; // Start at the end
                if(size(prefix) <= index && index < size(parts)) return just(parts[index]);
                return nothing();
            }, 
            sequences
        );
        suffix = reverse(reversedSuffix);
        // if([*f , l1, l2] := suffix) suffix = [l1, l2];
        warnings += suffixWarnings;

        // Find a further common prefix
        <prefixWarnings, prefixAugmentation> = findCommon(
            Maybe[ConvSymbol](list[ConvSymbol] parts, int index) {
                index += 1; // Skip the first index, since it's always included
                if(index < size(parts) - size(suffix)) return just(parts[index]);
                return nothing();
            },
            sequences
        );
        prefix += prefixAugmentation;
        warnings += prefixWarnings;

        // Extract the remainder sequence for every production
        set[SourceProd] sequenceSources = {};
        set[list[ConvSymbol]] mergeSequences = {};
        set[Symbol] outSequences = {};
        for(<parts, p> <- sequences) {
            startIndex = size(prefix);
            endIndex = size(parts) - size(suffix);
            remainder = parts[startIndex..endIndex];
            if(remainder == []) continue;

            sequenceSources += extractSources(remainder);

            // If we have a common suffix, add a lookahead to prevent symbol merging in sequence, 
            // but only if there's any regular expression, otherwise no sequence is created anyhow
            if([regexp(rs), *_] := suffix, [*_, regexp(_), *_] := remainder) {
                la = makeLookahead(rs);
                remainder += regexp(la);
            }

            <dWarnings, seqSym, grammar> = defineSequence(remainder, p, grammar);
            warnings += dWarnings;

            outSequences += seqSym;
        }

        // Extract the non-regex prefix of the suffix (if any) into the recursion
        while([s:ref(refSym, scopes, _), *lastParts] := suffix){
            outSequences += refSym;
            if(size(scopes) > 0) warnings += inapplicableScope(s, baseProd);
            suffix = lastParts;
        }

        // Define the final production
        combinedParts = prefix + [ref(simplify(unionRec(outSequences), grammar), [], sequenceSources)] + suffix;       
        return <warnings, combinedParts, grammar>;
    }
}

@doc {
    Finds a common prefix/suffix between the given productions
}
WithWarnings[list[ConvSymbol]] findCommon(
    Maybe[ConvSymbol](list[ConvSymbol] parts, int index) getPart,
    set[SourcedSequence] sequences
) {
    if({<baseParts, baseProd>, *restSequences} := sequences) {
        list[tuple[ConvSymbol, Maybe[Warning]]] out = [];
        int i = 0;
        outer: while(true) {
            bool same = true;
            part = getPart(baseParts, i);

            set[tuple[Symbol, ScopeList]] incompatibleScopes = {};
            set[ConvProd] incompatibleScopesSources = {};

            // Check if all symbols are equivalent 
            set[SourceProd] newSources = {};
            for(<parts, p> <- restSequences) {
                comparePart = getPart(parts, i);
                if(just(regexp(r)) := part) {
                    if (just(regexp(r2)) := comparePart){
                        if(!regex::PSNFATools::equals(r, r2))
                            same = false;
                        else 
                            newSources += extractAllRegexSources(r2);
                    } else same = false;
                } else if(just(ref(refSym, scopes, _)) := part) {
                    if (just(ref(refSym2, scopes2, sources)) := comparePart) {
                        if(refSym != refSym2) {
                            same = false;
                        } else if(scopes != scopes2) {
                            incompatibleScopes += {<refSym2, scopes2>, <refSym, scopes>};
                            incompatibleScopesSources += {p, baseProd};
                        } else {
                            newSources += sources;
                        }
                    } else same = false;
                } else same = false;

                if(!same) break outer;
            }

            // If not equal, we hit the end
            if(!same) break outer;

            // Add the new part and continue
            if(just(p) := part) {
                p = applyScopesAndSources(p, [], newSources);

                // Add warnings if scopes are incompatible
                if(incompatibleScopes != {}) {
                    out += <p, just(incompatibleScopesForUnion(
                        incompatibleScopes, 
                        incompatibleScopesSources
                    ))>;
                } else {
                    out += <p, nothing()>;
                }
            }

            i += 1;
        }

        // // Make sure we end on a regular expression
        // while([*firstParts, lastPart] := out, <regexp(_), _> !:= lastPart)
        //     out = firstParts;

        // Extract the generated warnings and prefix
        return <[warning | <_, just(warning)> <- out], [part | <part, _> <- out]>;
    }
}