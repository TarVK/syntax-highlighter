module conversion::determinism::fixNullableRegexes

import ParseTree;
import Relation;
import Map;
import List;
import IO;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::makePrefixedRightRecursive;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::shapeConversion::deduplicateProductions;
import conversion::util::RegexCache;
import regex::RegexTypes;
import regex::PSNFATools;
import regex::RegexTransformations;
import regex::NFA;
import Warning;

@doc {
    Removes nullability from regular expressions that would lead to infinite self-loops.
    
    It does this by detecting loops with nullable regexes, and expanding productions of any symbols in this loop into all other symbols, and also creates a non-nullable version of the productions that cause the issue. 

    E.g.
    ```
    A -> b? B c? C d D
    A -> e? E d D
    B -> a? A
    C -> a? A
    D -> d D
    E -> e E
    ```
    =>
    ```
    A -> b A c? A d D
    A -> c A d D
    A -> d D
    A -> a A
    A -> e? E d D
    D -> d D
    E -> e E
    ```
}
WithWarnings[ConversionGrammar] fixNullableRegexes(ConversionGrammar grammar){
    list[Warning] warnings = [];

    // Detect the empty paths
    prods = Relation::index(grammar.productions);
    paths = findEmptyPaths(prods);

    while(size(paths)>0) {
        // Resolve the empty paths
        newProds = prods;
        for(sym <- paths) {
            <symWarnings, newSymProds> = removeEmptyPaths(sym, paths[sym], prods);
            newProds[sym] = newSymProds;
            warnings += symWarnings;
        }
        grammar.productions = toRel(newProds);

        // Merge symbols that may be adedd by resolving paths
        <combineWarnings, grammar> = combineConsecutiveSymbols(grammar);
        warnings += combineWarnings;

        // Remove duplicate symbols and productions
        grammar = deduplicateProductions(grammar);

        // Recalculate, new union symbols might have introduced new paths
        prods = Relation::index(grammar.productions);
        paths = findEmptyPaths(prods);
    }


    return <warnings, grammar>;
}

WithWarnings[set[ConvProd]] removeEmptyPaths(Symbol sym, set[EmptyPath] symLoops, ProdMap prods) {
    list[Warning] warnings = [];

    set[ConvProd] outProds = prods[sym];

    // Collect all new things to include in this production, and the productions to removbe
    set[ConvProd] deleteProds = {};
    set[Symbol] includeSymbols = {};
    set[ConvProd] remainderProds = {};
    for(loop <- symLoops) {
        for(<prod, loopIndex> <- loop) {
            deleteProds += prod;
            for(i <- [0..loopIndex+1]) {
                part = prod.parts[i];
                if(symb(iSym, scopes) := part) {
                    if(size(scopes)>0)
                        warnings += inapplicableScope(scopes, prod);
                    includeSymbols += getWithoutLabel(iSym);
                } else if(regexp(regex) := part) {
                    <nonEmpty, _, _> = factorOutEmpty(regex);
                    if(nonEmpty != never()) {
                        followParts = prod.parts[i+1..];
                        remainderProds += convProd(copyLabel(prod.symb, sym), [regexp(nonEmpty), *followParts], {convProdSource(prod)});
                    }
                }
            }

            if(size(prod.parts) > loopIndex+1)
                remainderProds += convProd(copyLabel(prod.symb, sym), prod.parts[loopIndex+1..], {convProdSource(prod)});
        }
    }
    includeSymbols -= sym;

    // Create all productions
    outProds += remainderProds;
    outProds -= deleteProds;
    for(iSym <- includeSymbols) {
        includeProds = prods[iSym];
        for(p:convProd(lDef, parts, _) <- includeProds) {
            if(size(parts) == 0) continue;
            if(p in deleteProds) continue;
            outProds += convProd(copyLabel(lDef, sym), [*parts, symb(sym, [])], {convProdSource(p)});
        }
    }

    return <warnings, outProds>;
}

/*
  Find loops in the grammar
*/
alias EmptyPath = list[tuple[
    ConvProd production, 
    int recIndex
]];

@doc {
    Finds all empty paths where either a non-productive loop of any type is reached. E.g. 
    ```
    A -> /(> a|b)/ B
    B -> /(> a)/ A
    ```
    or a path exists that's not necessarily a loop, but that can always be taken independent of the next/prvious characters:
    ```
    A -> /a?/ B
    B -> /b/ B
    ```
}
map[Symbol, set[EmptyPath]] findEmptyPaths(ProdMap prods) {    
    map[Symbol, set[EmptyPath]] paths = ();
    for(sym <- prods) {
        symPaths = findEmptyPaths(sym, Regex::empty(), [], prods);;
        if(size(symPaths)>0)
            paths[sym] = symPaths;
    } 

    return paths;
}

set[EmptyPath] findEmptyPaths(Symbol sym, Regex emptyRegex, EmptyPath path, ProdMap prods) {
    // If we reached a loop while still not being forced to consume anything, output the path
    if([<convProd(lDef, _, _), _>, *_] := path, getWithoutLabel(lDef) == sym)
        return {path};

    if(any(<convProd(lDef, _, _), _> <- path, getWithoutLabel(lDef) == sym))
        return {}; // We encounter a loop so we want to stop recursion, but the first element on the path isn't involved in this loop

    set[EmptyPath] paths = {};
    if(sym in prods) {
        for(p:convProd(_, parts, _) <- prods[sym]) {
            newEmptyRegex = emptyRegex;

            int index = 1;
            while([regexp(r), symb(subSym, _), *rest] := parts) {
                if(!acceptsEmpty(r)) break; // If the first regex doesn't accept the empty string, there's no empty cycle

                newPath = [*path, <p, index>];
                // If we can always accept the empty string regardless of lookahead/behind, the regex is not productive at all and should be considered in the empty paths
                if(alwaysAcceptsEmpty(r)) paths += newPath;

                newEmptyRegex = concatenation(newEmptyRegex, r);
                if(isEmpty(regexToPSNFA(newEmptyRegex))) break; // If the language of the concatenation becomes empty (due to contradicting restrictions), this can't be matched in a cycle

                paths += findEmptyPaths(subSym, newEmptyRegex, newPath, prods);

                parts = rest;
                index += 2;
            }
        }
    }

    return paths;
}