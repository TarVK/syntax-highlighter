module conversion::determinism::combineOverlapOld

import Set;
import util::Maybe;
import IO;

import util::List;
import regex::Regex;
import conversion::util::RegexCache;
import conversion::util::combineLabels;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::defineUnionSymbols;
import conversion::determinism::improveAlternativesOverlap;
import conversion::shapeConversion::customSymbols;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::combineConsecutiveSymbols;
import regex::PSNFATools;
import Scope;
import Warning;

data Warning = mergeScopeDifferences(tuple[Regex, ConvProd] primary, set[tuple[Regex, ConvProd]] regexOverlaps)
             | incompatibleScopesForUnion(set[tuple[Symbol, Scopes]], set[ConvProd] productions);

@doc {
    Attempts to combine productions that start with overlapping regular expressions

    E.g.
    ```
    A -> X B
    A -> X C
    ```
    =>
    ```
    A -> X BC
    BC -> ...B
    BC -> ...C
    ```
}
WithWarnings[ConversionGrammar] combineOverlap(
    ConversionGrammar grammar, 
    ConversionGrammar exactGrammar,
    int maxLookaheadLength
) {
    list[Warning] warnings = [];

    println("start-combine");

    symbols = grammar.productions<0>;
    while(size(symbols) > 0) {
        subsets = getSubsetSymbols(grammar);
        set[Symbol] modifiedSymbols = {};
        for(sym <- symbols) {
            <newWarnings, grammar, newModified, subsets> 
                = combineOverlap(sym, grammar, exactGrammar, maxLookaheadLength, subsets);
            warnings += newWarnings;
            modifiedSymbols += newModified;
        }

        <newWarnings, symbols, grammar> = defineUnionSymbols(grammar);
        warnings += newWarnings;
        symbols += modifiedSymbols;
    }
    return <warnings, grammar>;
}

tuple[
    list[Warning] warnings, 
    ConversionGrammar grammar,
    set[Symbol] modifiedSymbols, 
    rel[Symbol, Symbol] subsets
] combineOverlap(
    Symbol sym, 
    ConversionGrammar grammar,
    ConversionGrammar exactGrammar,
    int maxLookaheadLength, 
    rel[Symbol, Symbol] subsets
) {
    bool stable = false;
    list[Warning] warnings = [];
    set[Symbol] modifiedSymbols = {};
    while(!stable) {
        prods = [p | p<-grammar.productions[sym]];
        stable = true;

        for(
            i <- [0..size(prods)], 
            prod:convProd(_, [regexp(rm), *_], _) := prods[i],
            !acceptsEmpty(rm)
        ) {
            set[ConvProd] overlap = {
                p
                | p:convProd(_, [regexp(ri), *_], _) <- prods,
                p != prod,
                just(_) := getOverlap(ri, rm) || just(_) := getOverlap(rm, ri)
                // isSubset(ri, rm, true)
            }; 

            if(size(overlap) > 0) {
                <newWarnings, grammar, newModified> 
                    = combineProductions(prod, overlap, grammar, exactGrammar, maxLookaheadLength, subsets);
                warnings += newWarnings;
                modifiedSymbols += newModified;
                stable = false;
                subsets = getSubsetSymbols(grammar);

                break;
            }
        }
    }

    return <warnings, grammar, modifiedSymbols, subsets>;
}

tuple[
    list[Warning] warnings, 
    ConversionGrammar grammar,
    set[Symbol] modifiedSymbols
] combineProductions(
    ConvProd main:convProd(mSym, [regexp(rm), *restM], _), 
    set[ConvProd] included, 
    ConversionGrammar grammar,
    ConversionGrammar exactGrammar,
    int maxLookaheadLength,
    rel[Symbol, Symbol] subsets
) {
    list[Warning] warnings = [];

    allProds = included + {main};
    labels = [name | <_, convProd(label(name, _), _, _)> <- allProds];
    plainSym = getWithoutLabel(mSym);
    labeledSym = size(labels)>0 ? label(stringify(labels, ","), plainSym) : plainSym;

    <dWarnings, grammar, modifiedSymbols, allShortenedProds> 
        = removeDanglingExpressions(allProds, grammar, exactGrammar, maxLookaheadLength, subsets);
    warnings += dWarnings;

    delProds = {<getWithoutLabel(lDef), prod> | prod:convProd(lDef, _, _) <- allProds};
    grammar.productions -= delProds;
    if({prod:convProd(lDef, _, _)} := allShortenedProds) {
        grammar.productions += {<getWithoutLabel(lDef), prod>};
        return <warnings, grammar, modifiedSymbols>;
    }

    list[ConvSymbol] outParts = [];
    void addPart(set[ConvSymbol] options, bool shouldBeRegex) {
        regexes = {r | regexp(r) <- options};
        symbols = {sym | symb(sym, _) <- options};

        if(shouldBeRegex) {
            if(size(symbols)>0) throw <"Encountered unexpected symbols", symbols>;
            mergedRegex = mergeRegex(regexes);
            cachedRegex = getCachedRegex(mergedRegex);
            outParts += regexp(cachedRegex);
        } else {
            if(size(regexes)>0) throw <"Encountered unexpected regexes", regexes>;

            scopeOpts = {scopes | symb(_, scopes) <- options};
            <mostCommonScopes, _> = (<getOneFrom(scopeOpts), 0> 
                | it<1> > count ? it : <scopes, count>
                | scopes <- scopeOpts, count :=  size([0 | sym(_, scopes) <- options]));

            if(size(scopeOpts)>1)
                warnings += incompatibleScopesForUnion(
                    {<sym, scopes> | symb(sym, scopes) <- options}, 
                    allShortenedProds);

            mergedSym = unionSym(symbols, {});
            outParts += symb(mergedSym, mostCommonScopes);
        }
    }

    /**
        Merge everything but the last 3 shared symbols one to one. Then merge the last 2 symbols regularly one to one. Finally combine all other symbols inbetween.
        E.g.
        ```
        A -> X B Y C Z A
        A -> X D W E V F U A        
        ```
        =>
        ```
        A -> X BD (Y | W) CEVF (Z | U) A
        BD -> ...B
        BD -> ...D
        CBVF -> V CBVF
        CBVF -> ...C
        CBVF -> ...E
        CBVF -> ...F
        ```
    */
    
    minLength = (size(restM)+1 | it < l ? it : l | convProd(_, p, _) <- allShortenedProds, l := size(p));
    sequences = {parts | convProd(_, parts, _) <- allShortenedProds};
    for(i <- [0..minLength-3]) {
        shouldBeRegex = i%2==0;
        options = {sequence[i] | sequence <- sequences};
        addPart(options, shouldBeRegex);
    }

    void mergeBody(int until) {
        set[Symbol] mergeSymbols = {};
        set[tuple[Regex, set[SourceProd]]] mergeRegexes = {};
        set[tuple[Symbol, Scopes]] incompatibleScopes = {};
        set[ConvProd] incompatibleScopesProds = {};

        startIndex = minLength-3;
        if(startIndex<1) startIndex = 1;

        for(prod:convProd(_, sequence, _) <- allShortenedProds) {
            for(i <- [startIndex..size(sequence)+until]) {
                part = sequence[i];
                if(symb(sym, scopes) := part) {
                    if(size(scopes) > 0) {
                        incompatibleScopes += <sym, scopes>;
                        incompatibleScopesProds += prod;
                    }
                    mergeSymbols += sym;
                } else if(regexp(r) := part)
                    mergeRegexes += <r, {convProdSource(prod)}>;
            }
        }
        outParts += symb(unionSym(mergeSymbols, mergeRegexes), []);

        if(size(incompatibleScopes)>0)
            warnings += incompatibleScopesForUnion(incompatibleScopes, incompatibleScopesProds);
    }

    if(minLength < 3) {
        /** 
            We have to resort to merging without a closing regex, e.g.:
            ```
            A -> X A
            A -> X B Y A
            ```
            =>
            ```
            A -> X ABY
            ABY -> ...A
            ABY -> ...B
            ABY -> Y ABY
            ```
        */
        mergeBody(0); // Merge everything that remains
    } else {
        mergeBody(-2); // Merge the remainder regexes and non-terminals, except for the last 2 symbols of each production        

        closingOptions = {seq[size(seq)-2] | seq <- sequences};
        addPart(closingOptions, true);

        recSymbols = {seq[size(seq)-1] | seq <- sequences};
        addPart(recSymbols, false);
    }
    
    grammar.productions += {<
        getWithoutLabel(mSym), 
        convProd(
            combineLabels(mSym, {s | convProd(s, _, _) <- allShortenedProds}), 
            outParts, 
            {convProdSource(p) | p <- allShortenedProds}
        )
    >};

    return <warnings, grammar, modifiedSymbols>;
}

Regex mergeRegex(set[Regex] regexes) {
    reducedRegexes = removeSelfIncludedRegexes({<r, {}> | r <- regexes});
    return reduceAlternation(Regex::alternation([r | <r, _> <- reducedRegexes]));
}

@doc {
    Tries to remove dangling expressions in a set of productions whenever possible, assuming all symbols are right recursive:
    ```
    A -> X A Y A
    ```
    =>
    ```
    A -> X A 
    A -> Y A
    ```   

    Note that the removed partss (`Y A` in the example above) are directly added to the grammar, while the prefixes of what remains from the original rules are returned. I.e. the example above would return the following data:
    Grammar:
    ```
    A -> X A Y A 
    A -> Y A
    ```
    Productions set:
    ```
    {A -> X A}
    ```
}
tuple[
    list[Warning] warnings, 
    ConversionGrammar grammar, 
    set[Symbol] modifiedSymbols,
    set[ConvProd] remainingProds
] removeDanglingExpressions(
    set[ConvProd] prods, 
    ConversionGrammar grammar, 
    ConversionGrammar exactGrammar,
    int maxLookaheadLength,
    rel[Symbol, Symbol] subsets
) {
    list[Warning] warnings = [];

    if(size(prods)<=1) return <warnings, grammar, prods>;
    set[Symbol] modifiedSymbols = {};

    bool stable = false;
    while(!stable) {
        stable = true;

        for(p:convProd(lDef, [
                *prodPrefix, 
                symb(innerSym, innerScopes), 
                regexp(r), 
                symb(recSym, recScopes)
            ], _) <- prods
        ) {
            if(<getWithoutLabel(innerSym), getWithoutLabel(recSym)> notin subsets) continue;

            isClosing = any(
                p2:convProd(_, [*_, _, regexp(c), symb(_, _)], _) <- prods,
                p2 != p,
                isSubset(r, c, true) || isSubset(c, r, true)
            );

            // In case this last regex is shared with any other production, we use it as a scope closing identifier instead
            if(isClosing) continue;

            bool overlaps(Symbol sym) = any(p2:convProd(_, [regexp(r2), *_], _) <- grammar.productions[sym], 
                just(_) := getOverlap(r, r2) || just(_) := getOverlap(r2, r));
                
            recSymDef = followAliases(recSym, grammar);
            innerSymDef = followAliases(innerSym, grammar);

            overlapsRec = overlaps(recSymDef);
            overlapsInner = overlaps(innerSymDef);
            if(overlapsRec && !overlapsInner) continue; // In this case it's safe to use `r` as a closing identifier for the innerSym, but not as an arbitrary matcher for recSym, hence it may be safer to not strip it out

            if(innerScopes != recScopes)
                warnings += incompatibleScopesForUnion({<innerSym, innerScopes>, <recSym, recScopes>}, p);


            tailProd = convProd(
                copyLabel(lDef, recSymDef), 
                [regexp(r), symb(recSymDef, [])], 
                {convProdSource(p)}
            );
            includesTailProd = any(pr <- grammar.productions[recSymDef], prodIsSubset(tailProd, pr, subsets, true));
            if(!includesTailProd) {
                grammar.productions += {<recSymDef, tailProd>};
                modifiedSymbols += recSymDef;
            }

            prods -= p;
            prods += convProd(lDef, [*prodPrefix, symb(recSym, recScopes)], {convProdSource(p)});

            stable = false;
        }
    }

    // Deduplicate output prods
    for(prod:convProd(lDef, parts, _) <- prods) {
        if(prod notin prods) continue; // If removed in a previous iteration

        duplicates = {p | p <- prods, p==prod || prodsEqual(p, prod, (), true)};
        if(size(duplicates) > 1) {
            prods -= duplicates;
            prods += convProd(
                combineLabels(lDef, {s | convProd(s, _, _) <- duplicates}),
                parts, 
                {convProdSource(p) | p <- duplicates}
            );
        }
    }

    return <warnings, grammar, modifiedSymbols, prods>;
}

@doc {
    Follows an alias symbol until the defining symbol that it's an alias is for is reached
}
Symbol followAliases(Symbol sym, ConversionGrammar grammar) {
    while({convProd(_, [symb(ref, _)], _)} := grammar.productions[sym]) {
        sym = getWithoutLabel(ref);
    }
    return sym;
}

// tuple[set[Symbol] modifiedSymbols, ConversionGrammar] addRegexToSymbol()