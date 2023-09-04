module conversion::determinism::expandFollow

import Relation;
import Set;
import util::Maybe;
import IO;
import Map;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;
import regex::PSNFA;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::Regex;

alias LACache = map[tuple[
    Maybe[Regex] target,
    list[ConvSymbol] parts, 
    int length
], Regex];

@doc {
    Attempts to add lookaheads to the first regexes of productions in the grammar to prevent overlap between alternations
}
ConversionGrammar fixOverlap(
    ConversionGrammar grammar, 
    int maxLookahead
)
    = fixOverlap(grammar, grammar.productions<0>, maxLookahead);
    
ConversionGrammar fixOverlap(
    ConversionGrammar grammar, 
    set[Symbol] symbols,
    int maxLookahead
) {
    LACache cache = ();
    ProdMap prods = Relation::index(grammar.productions);

    for(sym <- domain(prods) & symbols) {
        stable = false;
        while(!stable) {
            alternations = [*prods[sym]];
            stable = true;

            outer: for(
                i <- [0..size(alternations)],
                pa:convProd(_, [regexp(ra), *_], _) := alternations[i]
            ) {
                for(
                    j <- [i+1..size(alternations)],
                    pb:convProd(_, [regexp(rb), *_], _) := alternations[j]
                ) {
                    if(
                        just(_) := getOverlap(ra, rb)
                        || just(_) := getOverlap(rb, ra)
                    ) {
                        <fix, cache> = fixOverlap(pa, pb, prods, maxLookahead, cache);

                        if(just(<newPa, newPb>) := fix) {
                            grammar.productions -= {<sym, pa>, <sym, pb>};
                            grammar.productions += {<sym, newPa>, <sym, newPb>};
                            prods = Relation::index(grammar.productions);

                            stable = false;
                            break outer;
                        } 
                        // TODO: if fix fails, try use definitions extracted from regular symbols, e.g. for `"%" ![%]+ "%"` we could extract all required data from `![%]+`, rather than the current definition of the grammar (which will be nullable)
                    }
                }
            }
        }
    }

    return grammar;
}

@doc {
    Attempts to add lookaheads to the first regexes of the given productions to solve overlap
}
tuple[
    Maybe[tuple[ConvProd, ConvProd]],
    LACache
 ] fixOverlap(
    ConvProd pa, 
    ConvProd pb, 
    ProdMap prods,
    int maxLookahead,
    LACache cache
) {
    if(
        convProd(aDef, allPartsA:[regexp(ra), *partsA], aSources) := pa,
        convProd(bDef, allPartsB:[regexp(rb), *partsB], bSources) := pb
    ) {
        <res, cache> = fixOverlap(allPartsA, allPartsB, prods, maxLookahead, cache);
        if(just(<newA, aLength, newB, bLength>) := res)
            return <just(<
                convProd(aDef, [regexp(newA), *partsA], aLength==0?aSources:{convProdSource(pa)}),
                convProd(bDef, [regexp(newB), *partsB], bLength==0?bSources:{convProdSource(pb)})
            >), cache>;
    }

    return <nothing(), cache>;
}

@doc {
    Attempts to add a lookahead for the following symbols to regex a and or b in order to fix overlap
}
tuple[
    Maybe[tuple[
        Regex newRa, 
        int lookaheadLengthA,
        Regex newRb,
        int lookaheadLengthB
    ]],
    LACache
 ] fixOverlap(
    [regexp(ra), *partsA], 
    [regexp(rb), *partsB], 
    ProdMap prods,
    int maxLookahead,
    LACache cache
) {
    lengthCombinations = sort(
        ([0..maxLookahead+1] * [0..maxLookahead+1]) - <0, 0>,
        // TODO: this ordering could affect "reponsiveness" of a grammar, so it would be good for this to be tweakable as a parameter
        bool (<ia, ja>, <ib, jb>) {
            return ia + ja < ib + jb || ia + ja == ib + jb && abs(ia - ja) < abs(ib - jb);
        }
    );

    
    Regex getExpanded(Regex r, list[ConvSymbol] parts, int length) {
        if(length==0) return r;
        if(containsNewline(r)) return r;

        fullKey = <just(r), parts, length>;
        if(fullKey in cache) return cache[fullKey];

        laKey = <nothing(), parts, length>;

        la = laKey in cache 
            ? cache[laKey]
            : getCachedRegex(getLookahead(parts, length, prods, {}));
        expanded = getCachedRegex(lookahead(r, la));

        cache[laKey] = la;
        cache[fullKey] = expanded;

        return expanded;
    }

    for(<aLength, bLength> <- lengthCombinations) {
        expandedA = getExpanded(ra, partsA, aLength);
        expandedB = getExpanded(rb, partsB, bLength);
        if(
            nothing() := getOverlap(expandedA, expandedB), 
            nothing() := getOverlap(expandedB, expandedA)
        ) {
            return <just(<expandedA, aLength, expandedB, bLength>), cache>;
        }
    }

    return <nothing(), cache>;
}



@doc {
    Retrieves the lookahead for a given sequence of parts
}
Regex getLookahead(list[ConvSymbol] parts, int length, ProdMap prods, set[Symbol] visited) {
    if(length<=0) return empty();

    list[Regex] la = [];
    for(i <- [0..size(parts)] && i < length) {
        part = parts[i];
        if(regexp(r) := part) {
            la += r;
            if(containsNewline(r))
                break;
        } else if(symb(s, _) := part) {
            s = getWithoutLabel(s);

            // Prevent infinite left-recusive loops
            if(i!=0) visited = {};
            else {
                if(s in visited) 
                    return never();
                visited += s;
            }

            alternatives = prods[s];
            list[Regex] options = [];
            for(convProd(_, altParts, _) <- alternatives)
                options += getLookahead(
                    [*altParts, *parts[i+1..]], 
                    length - i, 
                    prods, 
                    visited
                );

            la += reduceAlternation(alternation(options));
        }
    }

    return reduceConcatenation(concatenation(la));
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

int abs(int v) = v < 0 ? -v : v;