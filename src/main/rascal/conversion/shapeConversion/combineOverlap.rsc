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
import Logging;
import TestConfig;

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
] combineOverlap(set[ConvProd] prods, ConversionGrammar grammar, TestConfig testConfig) {
    testConfig.log(ProgressDetailed(), "finding productions to combine");
    map[NFA[State], set[ConvProd]] indexed = ();
    set[ConvProd] out = {};

    // Index all productions into groups with overlap
    for(p:convProd(_, parts) <- prods){
        if([regexp(r), *_] := parts)
            indexed = addToIndex(indexed, r, p);
        else
            out += p; // Empty prods
    }

    // Add all productions to output
    list[Warning] warnings = [];
    for(group <- indexed<1>) {
        if({p} := group) {
            out += p;
        } else {
            testConfig.log(ProgressDetailed(), "combining <size(group)> productions");
            <nWarnings, newProd, grammar> = combineProductions(group, grammar, testConfig);
            testConfig.log(ProgressDetailed(), "productions combined");
            warnings += nWarnings;
            out += newProd;
        }
    }
    return <warnings, out, grammar>;
}

@doc {
    Adds a given regular expression to the index of regular expressions
}
map[NFA[State], set[&T]] addToIndex(map[NFA[State], set[&T]] indexed, Regex r, &T satelliteData) {
    nfa = regexToPSNFA(r);
    if(nfa in indexed) {
        indexed[nfa] += satelliteData;
    } else {
        overlapNfas = {nfa2 | nfa2 <- indexed, overlaps(nfa, nfa2)};
        if({} := overlapNfas) {
            indexed[nfa] = {satelliteData};
        } else {
            combinedSatelliteData = {satelliteData};
            for(nfa2 <- overlapNfas) {
                combinedSatelliteData += indexed[nfa2];
                nfa = unionPSNFA(nfa, nfa2);
                indexed = delete(indexed, nfa2);
            }
            indexed[nfa] = combinedSatelliteData;
        }
    } 
    return indexed;
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
] combineProductions(set[ConvProd] prods, ConversionGrammar grammar, TestConfig testConfig) {
    <warnings, combinedParts, grammar> = combineSequences({<parts, p> | p:convProd(_, parts) <- prods}, grammar, testConfig);

    lDef = getOneFrom(prods).def;
    combinedLabelDef = combineLabels(lDef, {lDef2 | convProd(lDef2, _) <- prods});
    outProd = convProd(combinedLabelDef, combinedParts);
    
    return <warnings, outProd, grammar>;
}
    
tuple[
    list[Warning] warnings,
    list[ConvSymbol] sequence,
    ConversionGrammar grammar  
] combineSequences(set[SourcedSequence] sequences, ConversionGrammar grammar, TestConfig testConfig) {
    list[Warning] warnings = [];
    if({<baseParts:[regexp(r), *_], baseProd>, *restSequences} := sequences) { 
        // Make sure the first regex is always included in the prefix, even if the regexes only overlap but aren't equivalent
        list[ConvSymbol] prefix = [];
        prefix += regexp(combineExpressions(r + {r2 | <[regexp(r2), *_], _> <- restSequences}));

        // Find a common suffix
        <suffixWarnings, reversedSuffix> = findCommon(
            Maybe[ConvSymbol](list[ConvSymbol] parts, int index) {
                index = size(parts) - index - 1; // Start at the end
                if(size(prefix) <= index && index < size(parts)) return just(parts[index]);
                return nothing();
            }, 
            sequences,
            true, // Helps prevent blowups, but might decrease accuracy
            testConfig.overlapFinishRegex
        );
        suffix = reverse(reversedSuffix);
        warnings += suffixWarnings;

        // Find a further common prefix
        <prefixWarnings, prefixAugmentation> = findCommon(
            Maybe[ConvSymbol](list[ConvSymbol] parts, int index) {
                index += 1; // Skip the first index, since it's always included
                if(index < size(parts) - size(suffix)) return just(parts[index]);
                return nothing();
            },
            sequences,
            true, // Would be merged at a later stage anyhow, thus won't result in less accuracy
            testConfig.overlapFinishRegex
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

            <dWarnings, seqSym, grammar> = defineSequence(remainder, p, grammar, testConfig);
            warnings += dWarnings;

            outSequences += seqSym;
        }

        // Extract the non-regex suffix of the prefix (if any) into the recursion (and prefix of suffix)
        while([*firstParts, s:ref(refSym, scopes, _)] := prefix){
            outSequences += refSym;
            if(size(scopes) > 0) warnings += inapplicableScope(s, baseProd);
            prefix = firstParts;
        }
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
    Combines the given regular expressions, trying to not duplicate the same expressions in the union
}
Regex combineExpressions(set[Regex] rs) {
    if({r, *rRest} := rs) {
        for(Regex r2 <- rRest) {
            if(equals(r2, r) || isSubset(r2, r)) {
                r = addRegexSources(r, extractAllRegexSources(r2));
            } else if(isSubset(r, r2)) {
                r = addRegexSources(r2, extractAllRegexSources(r));
            } else {
                r = getCachedRegex(alternation(r, r2));
            }
        }
        return r;
    }
}

@doc {
    Finds a common prefix/suffix between the given productions
}
WithWarnings[list[ConvSymbol]] findCommon(
    Maybe[ConvSymbol](list[ConvSymbol] parts, int index) getPart,
    set[SourcedSequence] sequences,
    bool combineSequenceOverlap, // Whether to make overlapping regular expressions part of the prefix if not equal
    bool finishRegex // Whether the overlapping sequence should end in a regular expression
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
            map[NFA[State], set[Regex]] indexed = ();
            if(just(regexp(r)) := part) {
                if(combineSequenceOverlap) {
                    indexed = addToIndex(indexed, r, r);

                    for(<parts, p> <- restSequences) {
                        comparePart = getPart(parts, i);
                        if (just(regexp(r2)) := comparePart)
                            indexed = addToIndex(indexed, r2, r2);
                        else break outer;
                    }

                    // If our index only contains 1 entry, all regular expressions overlap and can be comvbined
                    if(size(indexed) != 1) break outer;
                    regexes = indexed[getOneFrom(indexed)];
                    part = just(regexp(combineExpressions(regexes)));
                } else {
                    for(<parts, p> <- restSequences) {
                        comparePart = getPart(parts, i);
                        if (
                            just(regexp(r2)) := comparePart, 
                            regex::PSNFATools::equals(r, r2)
                        ) 
                            newSources += extractAllRegexSources(r2);
                        else break outer; 
                    }
                }
            } else if(just(ref(refSym, scopes, _)) := part) {
                for(<parts, p> <- restSequences) {
                    comparePart = getPart(parts, i);
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

                    if(!same) break outer;
                }
            } else same = false;

            // If not equal, we hit the end
            if(!same) break outer;

            // Add the new part and continue
            if(just(p) := part) {
                if(newSources != {})
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

        if(finishRegex)
            // Make sure we end on a regular expression
            while([*firstParts, lastPart] := out, <regexp(_), _> !:= lastPart)
                out = firstParts;

        // Extract the generated warnings and prefix
        return <[warning | <_, just(warning)> <- out], [part | <part, _> <- out]>;
    }
}