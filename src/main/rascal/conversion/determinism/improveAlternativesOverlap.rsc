module conversion::determinism::improveAlternativesOverlap

import List;
import Map;
import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
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

data DeterminismTag = determinismTag(); // A regex tag used to identify that a lookahead only exists for determinism purposes, not for language correctness

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

Maybe[Regex] expandSymbolsToRegex(list[ConvSymbol] parts, ConversionGrammar grammar, int length) {
    seqOptions = expandSymbols(parts, grammar, length);

    Maybe[Regex] combineRegex(set[list[Regex]] seqOptions) {
        if(size(seqOptions)==0) return nothing();
        if([] in seqOptions) return nothing(); // If there's an empty option, all other lookahead alternations become redudant, since the empty will match those too.

        map[Regex, set[list[Regex]]] index = ();
        for([first, *rest] <- seqOptions) {
            if(first notin index) index[first] = {};
            index[first] += rest;
        }

        list[Regex] options = [];
        for(first <- index) {
            if(just(s) := combineRegex(index[first])) 
                options += concatenation(first, s);
            else 
                options += first;
        }

        // The below code does the same as this: 
        // return just(reduceAlternation(Regex::alternation(options)));
        // But this is erroring for seemingly no reason and I don't want to deal with this Rascal shit right now. 

        if([option] := options) return just(option);
        if([opt1, opt2, *rest] := options) return just((alternation(opt1, opt2) | alternation(it, part) | part <- rest));
        return nothing();
    }

    return combineRegex(seqOptions);
}

set[list[Regex]] expandSymbols(list[ConvSymbol] parts, ConversionGrammar grammar, int length) {
    map[Symbol, bool] nullableMap = ();
    bool isNullable(Symbol sym) {
        sym = getWithoutLabel(sym);
        if (sym in nullableMap) return nullableMap[sym];

        res = false;
        nullableMap[sym] = res; // Prevent loops caused by (A -> B; B -> A) productions
        prods = grammar.productions[sym];
        if (convProd(_, [], _) <- prods) res = true;
        else res = any(convProd(_, [symb(s, _)], _) <- prods, isNullable(s));
        nullableMap[sym] = res;
        return res;
    }

    set[list[ConvSymbol]] seqQueue = {};
    set[list[ConvSymbol]] encountered = {};
    set[list[Regex]] out = {};
    void addToQueue(list[ConvSymbol] seq) {
        if (seq in encountered) return;
        encountered += seq;
        cutSeq = seq[..length];
        encountered += cutSeq;

        // Recursively consider all cases where a symbol may be removed, before cutting off the suffix outside of the length
        if([*p, symb(sym, _), *s] := seq, isNullable(sym)) 
            addToQueue([*p, *s]);

        seqQueue += cutSeq;
        if(all(p <- cutSeq, regexp(_) := p)) 
            out += [r | regexp(r) <- cutSeq];
    }
    addToQueue(parts);

    while(size(seqQueue) > 0) {
        <sequence, seqQueue> = takeOneFrom(seqQueue);

        if([*p, symb(sym, _), *s] := sequence){
            for(convProd(_, subParts, _) <- grammar.productions[getWithoutLabel(sym)]) {
                if(size(subParts) == 0) continue; // This already has been considered during add to queue, before cutting off the tail
                
                addToQueue([*p, *subParts, *s]);
            }
        }
    }

    return out;
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