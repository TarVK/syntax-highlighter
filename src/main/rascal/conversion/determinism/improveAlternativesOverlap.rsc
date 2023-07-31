module conversion::determinism::improveAlternativesOverlap

import List;
import Map;
import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::determinism::expandSymbols;
import regex::Regex;
import regex::PSNFA;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::NFASimplification;
import regex::util::charClass;
import conversion::util::RegexCache;

alias ProdsOverlaps = set[ProdsOverlap];
alias ProdsOverlap = tuple[
    // The NFA encoding words accepted by the first regex of the first production, for which a prefix of the word is accepted by the first regex of the second production
    NFA[State], 
    // The first production which has overlap with another
    ConvProd, 
    // The second production which has overlap with another
    ConvProd
];

alias ProdExtensions = set[ProdExtension];
alias ProdExtension = tuple[
    ConvProd prod,
    int expansionLength
];

@doc {
    Computes overlap between the first regex of every pair of the given productions. If overlap is found, an attempt is made to fix this overlap using lookaheads limited to the specified maximum length. All overlaps that could not be fixed as well as extensions used to fix overlap are reported.
}
tuple[set[ConvProd], ProdsOverlaps, ProdExtensions] 
        improveAlternativesOverlap(set[ConvProd] prods, ConversionGrammar grammar, int maxLookaheadLength) {
    ProdsOverlaps overlaps = {};

    // Store the lookaheads that have already been computed to solve overlaps, as well as the original first regexes
    map[ConvProd, int] lookaheadLengths = (prod: 0 | prod <- prods);    
    map[ConvProd, list[ConvSymbol]] originalParts = (prod: parts | prod:convProd(_, parts, _) <- prods);

    outer: while(true) {
        overlaps = {};

        for(
            <
                a:convProd(aDef, [regexp(ra), *aRest], as), 
                b:convProd(bDef, [regexp(rb), *bRest], bs)
            > <- prods * prods
        ) {
            if(a==b) continue;

            if(just(overlap) := getOverlap(ra, rb)) {
                // Attempt to solve the overlap
                fix = fixOverlap(
                    originalParts[a],
                    lookaheadLengths[a],
                    originalParts[b],
                    lookaheadLengths[b],
                    grammar,
                    maxLookaheadLength);
                if(just(<newRa, newRaLALength, newRb, newRbLALength>) := fix) {
                    newA = convProd(aDef, [regexp(newRa), *aRest], as);
                    newB = convProd(bDef, [regexp(newRb), *bRest], bs);
                    lookaheadLengths[newA] = newRaLALength;
                    lookaheadLengths[newB] = newRbLALength;
                    originalParts[newA] = originalParts[a];
                    originalParts[newB] = originalParts[b];
                    prods = prods - a - b + newA + newB;

                    // Recompute everything with the newly added lookahead(s)
                    continue outer;
                } else {
                    // If the overlap couldn't be fixed, we want to report it
                    simplified = relabelSetPSNFA(minimize(overlap));
                    overlaps += <simplified, a, b>;
                }

                // TODO: attempt to fix alternatives overlap using negative lookaheads instead of positive ones.  This is more complex and requires me to have a PSNFA->regex conversion algorithm, but leads to more "responsive" highlighters
            }
        }

        // Note that we stop the outerlop, unless a fix causes a continue statement. Morover, every time a fix is found, one of the lookaheadLengths is increased. Hence at some point the maximum lookahead is always hit, at which point fix always returns nothing(), and thus the outer loop always terminates.
        break outer;
    }

    ProdExtensions extensions = {<prod, length> | <prod, length> <- toList(lookaheadLengths), length > 0};

    return <prods, overlaps, extensions>;
}

@doc {
    Attempts to extend the regular expressions with a lookahead to prevent overlap. Assumes that a prefix of a word accepted by ra is also accepted by rb, I.e. rb should be suffixed with a lookahead to prevent this. 

    Note that suffixes may be added to both ra and rb to resolve the conflict.
    Also note that adding a lookahead purely decreases the number of accepted words (when including context) of an expression. This is a fundamental property that this procedure relies on.
}
Maybe[tuple[
    Regex newRa, // The new regex a, with added lookahead
    int raLookaheadLength, // The number of terminals expanded into the lookahead of a
    Regex newRb, // The new regex b, with added lookahead
    int rbLookaheadLength // The number of terminals expanded into the lookahead of b
]] fixOverlap(
    [regexp(ra), *partsA], 
    int raMinLookaheadLength,  // Used in case another conflict already requires at least a lookahead of this length
    [regexp(rb), *partsB], 
    int rbMinLookaheadLength,  // Used in case another conflict already requires at least a lookahead of this length
    ConversionGrammar grammar, 
    int maxLength
) {
    // Define all valid suffix length combinations of ra and rb, in a semi-arbitrary order that prioritizes short lookaheads
    int abs(int v) = v < 0 ? -v : v;
    lengthCombinations = sort(
        ([raMinLookaheadLength..maxLength+1] * [rbMinLookaheadLength..maxLength+1]) 
            // Prevent considering the case where neither lookahead is extended
            - [raMinLookaheadLength, rbMinLookaheadLength],
        // TODO: this ordering could affect "reponsiveness" of a grammar, so it would be good for this to be tweakable as a parameter
        bool (<ia, ja>, <ib, jb>) {
            return ia + ja < ib + jb || ia + ja == ib + jb && abs(ia - ja) < abs(ib - jb);
        }
    );

    Maybe[Regex] getExpanded(Regex r, list[ConvSymbol] parts, int length) {
        if(length==0) return just(r);

        expansion = expandSymbolsToRegex(parts, grammar, length);
        if(just(expansionRegex) := expansion) {
            <expanded, _> = cachedRegexToPSNFA(lookahead(r, mark({determinismTag()}, expansionRegex)));
            return just(expanded);
        }
        return nothing();
    }

    for(<aLength, bLength> <- lengthCombinations) {
        if(
            just(expandedA) := getExpanded(ra, partsA, aLength) 
            && just(expandedB) := getExpanded(rb, partsB, bLength)
            && nothing() := getOverlap(expandedA, expandedB)
        ) 
            return just(<expandedA, aLength, expandedB, bLength>);
    }

    return nothing();
}


@doc {
    Checks whether an extension of rb overlaps with ra. I.e. whether a prefix of ra could also be matched by rb. 
}
Maybe[NFA[State]] getOverlap(Regex ra, Regex rb) {
    nfaA = regexToPSNFA(ra);
    nfaB = regexToPSNFA(rb);
    extensionB = getExtensionNFA(nfaB);
    overlap = productPSNFA(nfaA, extensionB, true);
    if(!isEmpty(overlap)) 
        return just(overlap);
    return nothing();
}