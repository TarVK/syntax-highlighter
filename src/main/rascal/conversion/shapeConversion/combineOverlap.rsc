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

import testing::util::visualizeGrammars;
import regex::Regex;

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
            } else if(nfa2 <- indexed, overlaps(nfa, nfa2)) {
                nfa2Prods = indexed[nfa2];

                // Index in a way that includes the full language
                if(isSubset(nfa, nfa2)) {
                    indexed[nfa] = nfa2Prods + p;
                    indexed = delete(indexed, nfa2);
                } else if(isSubset(nfa2, nfa)) {
                    indexed[nfa2] = nfa2Prods + p;
                } else {
                    cNfa = minimizeUnique(unionPSNFA(nfa, nfa2));
                    indexed[cNfa] = nfa2Prods + p;
                    indexed = delete(indexed, nfa2);
                }
            } else {
                indexed[nfa] = {p};
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
    list[Warning] warnings = [];
    if({baseProd:convProd(lDef, baseParts:[regexp(r), *_]), *restProds} := prods) {        
        // Make sure the first regex is always included in the prefix, even if the regexes only overlap but aren't equivalent
        list[ConvSymbol] prefix = [];
        for(p:convProd(_, [regexp(r2), *_]) <- restProds) {
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
            prods
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
            prods
        );
        prefix += prefixAugmentation;
        warnings += prefixWarnings;

        // Extract the remainder sequence for every production
        set[SourceProd] sequenceSources = {};
        set[Symbol] sequences = {};
        for(p:convProd(_, parts) <- prods) {
            startIndex = size(prefix);
            endIndex = size(parts) - size(suffix);
            remainder = parts[startIndex..endIndex];
            sequenceSources += extractSources(remainder);

            // If we have a common suffix, add a lookahead to prevent symbol merging in sequence
            if([regexp(rs), *_] := suffix) {
                la = makeLookahead(rs);
                remainder += regexp(la);
            }

            <dWarnings, seqSym, grammar> = defineSequence(remainder, p, grammar);
            warnings += dWarnings;

            sequences += seqSym;
        }

        // Extract the non-regex prefix of the suffix into the recursion
        while([s:ref(refSym, scopes, _), *lastParts] := suffix){
            sequences += refSym;
            if(size(scopes) > 0) warnings += inapplicableScope(s, baseProd);
            suffix = lastParts;
        }

        // Define the final production
        combinedParts = prefix + [ref(simplify(unionRec(sequences), grammar), [], sequenceSources)] + suffix;
        combinedLabelDef = combineLabels(lDef, {lDef2 | convProd(lDef2, _) <- prods});
        outProd = convProd(combinedLabelDef, combinedParts);
        
        return <warnings, outProd, grammar>;
    }
}

@doc {
    Finds a common prefix/suffix between the given productions
}
WithWarnings[list[ConvSymbol]] findCommon(
    Maybe[ConvSymbol](list[ConvSymbol] parts, int index) getPart,
    set[ConvProd] prods
) {
    if({baseProd:convProd(_, baseParts), *restProds} := prods) {
        list[tuple[ConvSymbol, Maybe[Warning]]] out = [];
        int i = 0;
        outer: while(true) {
            bool same = true;
            part = getPart(baseParts, i);

            set[tuple[Symbol, ScopeList]] incompatibleScopes = {};
            set[ConvProd] incompatibleScopesSources = {};

            // Check if all symbols are equivalent 
            set[SourceProd] newSources = {};
            for(p:convProd(_, parts) <- restProds) {
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

        // Extract the generated warnings and prefix
        return <[warning | <_, just(warning)> <- out], [part | <part, _> <- out]>;
    }
}