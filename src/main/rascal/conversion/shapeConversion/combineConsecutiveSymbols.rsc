module conversion::shapeConversion::combineConsecutiveSymbols

import ParseTree;
import Set;
import List;
import IO;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::compareProds;
import conversion::shapeConversion::util::getComparisonProds;
import conversion::util::RegexCache;
import Scope;
import Warning;
import Visualize;

data Warning = incompatibleScopesForUnion(set[tuple[Symbol, Scopes]], ConvProd source);

@doc {
    Combines all two (or more) consecutive non-terminal symbols together into their own symbol, which allows matching  of either. Assuming all rules are right-recursive, this broadens the language.
    E.g.
    ```
    A -> X C A
    C -> Y C
    ```
    =>
    ```
    A -> X CA
    C -> Y C
    CA -> X CA
    CA -> Y CA
    ```
}
WithWarnings[ConversionGrammar] combineConsecutiveSymbols(ConversionGrammar grammar) {
    list[Warning] warnings = [];

    prevGrammar = grammar;
    i = 0;
    do{
        prevGrammar = grammar;
        for(<sym, prod> <- grammar.productions) {
            <newWarnings, grammar> = combineConsecutiveSymbols(prod, grammar);
            warnings += newWarnings;
        }

        i += 1;
        if(i > 2) break;
    } while (prevGrammar != grammar);

    return <warnings, grammar>;
}

WithWarnings[ConversionGrammar] combineConsecutiveSymbols(prod:convProd(lDef, parts, sources), ConversionGrammar grammar) {
    list[Warning] warnings = [];

    set[set[Symbol]] addedBroadenings = {};

    list[ConvSymbol] newParts = [];

    set[tuple[Symbol, Scopes]] nonTerminals = {};
    void flushNonTerminals() {
        if({} := nonTerminals)
            ;
        else if({<ref, scopes>} := nonTerminals)
            newParts += symb(ref, scopes);
        else {
            symbols = {getWithoutLabel(s) | <s, _> <- nonTerminals};
            set[Symbol] flatSymbols = {};
            for(symbol <- symbols) {
                if(custom("union", \alt(ps)) := symbol) flatSymbols += ps;
                else flatSymbols += symbol;
            }
            definingSet = getDefiningSet(flatSymbols, grammar);

            scopeOpts = {scopes | <_, scopes> <- nonTerminals};
            addedBroadenings += {flatSymbols};
            if(size(scopeOpts)>1) 
                warnings += incompatibleScopesForUnion(nonTerminals, prod);


            if({ref} := definingSet)
                newParts += symb(ref, getOneFrom(scopeOpts));
            else
                newParts += symb(unionSym(definingSet), getOneFrom(scopeOpts));
        }
        nonTerminals = {};
    }

    for(part <- parts) {
        if(symb(ref, scopes) := part) {
            nonTerminals += <ref, scopes>;
        } else {
            flushNonTerminals();
            newParts += part;
        }
    }
    flushNonTerminals();

    if(size(addedBroadenings)==0) return <[], grammar>;

    pureDef = getWithoutLabel(lDef);
    grammar.productions -= {<pureDef, prod>};
    grammar.productions += {<pureDef, convProd(lDef, newParts, {convProdSource(prod)})>};

    for(broadening <- addedBroadenings) {
        grammar = addBroadening(broadening, grammar);
    }
    return <warnings, grammar>;
}

ConversionGrammar addBroadening(set[Symbol] symbols, ConversionGrammar grammar) {
    sym = unionSym(symbols);

    alreadyExists = size(grammar.productions[sym])>0;
    if(alreadyExists) return grammar;

    list[Warning] warnings = [];

    set[ConvProd] newProds = {};
    for(sourceSym <- symbols) {
        prods = grammar.productions[getWithoutLabel(sourceSym)];

        for(prod:convProd(lDef, parts, sources) <- prods) {
            list[ConvSymbol] newParts;
            if(size(parts) == 0) {
                // Empty productions should be copied literally without adding recursion
                newParts = parts;
            } else {
                end = size(parts);
                for(i <- reverse([0..end])) {
                    if(symb(ref, _) := parts[i]) {
                        contains = false;
                        if(custom("union", \alt(ps)) := ref) 
                            contains = ps <= symbols;
                        else
                            contains = getWithoutLabel(ref) in symbols;

                        if(contains){
                            end = i;
                            continue;
                        }
                    }

                    break;
                }

                newParts = parts[..end] + symb(sym, []); // Exclude all final symbols that are included in this sym
            }
            
            isNew = !any(convProd(_, p, _) <- newProds, p == newParts);
            if(isNew)
                newProds += convProd(copyLabel(lDef, sym), newParts, {convProdSource(prod)});
        }
    }

    grammar.productions += {<sym, prod> | prod <- newProds};
    return grammar;
}

@doc {
    Gets the set of symbols whose productions together include all productions present within the union of the productions of all provided symbols
}
set[Symbol] getDefiningSet(set[Symbol] symbols, ConversionGrammar grammar) {
    set[tuple[Symbol, set[ConvProd]]] symbolProds = {<sym, getComparisonProds(grammar.productions[sym])> | sym <- symbols};

    stable = false;
    while(!stable) {
        stable = true;

        for(p:<sym, prods> <- symbolProds) {
            rest = symbolProds - p;
            restProds = {*prods | <_, prods> <- rest};

            restIncludesProds = prods <= restProds;
            println(removeRegexCache(<prods, restProds>));
            if(restIncludesProds) {
                symbolProds = rest;
                stable = false;
                break;
            }
        }
    }

    return symbolProds<0>;
}


Symbol unionSym(set[Symbol] parts) = custom("union", \alt(parts));

// Symbol unionSym(set[Symbol] parts) {
//     set[Symbol] flatParts = {};
//     for(p <- parts) {
//         if(custom("union", \alt(ups)) := p)
//             flatParts += ups;
//         else
//             flatParts += p;
//     }

//     return custom("union", \alt(flatParts));
// }


tuple[
    
    list[Warning] warnings
] combineSymbols(set[tuple[Symbol, Scopes]] symbols) {

}