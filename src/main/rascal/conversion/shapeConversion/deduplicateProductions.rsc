module conversion::shapeConversion::deduplicateProductions

import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::getComparisonProds;
import conversion::shapeConversion::util::compareProds;
import conversion::util::RegexCache;

@doc {
    Deduplicates productions by detecting productions that are homomorphic and removing these duplicates.
    Assumes all rules in the grammar to be right-recursive, or an empty production
}
ConversionGrammar deduplicateProductions(ConversionGrammar grammar) {
    rel[Symbol, ConvProd] productions = grammar.productions;

    changed = true;
    while(changed) {
        changed = false;
        symbols = [s | s <- productions<0>];
        search: for(i <- [0..size(symbols)]) {
            iSym = symbols[i];
            iProds = productions[iSym];
            for(j <- [i+1..size(symbols)]) {
                jSym = symbols[j];
                jProds = productions[jSym];

                if(areEquivalent(iSym, iProds, jSym, jProds)) {
                    if (grammar.\start == iSym)
                        <iSym, jSym> = <jSym, iSym>; // Make sure to always keep the start symbol

                    productions = replaceSymbol(productions, iSym, jSym);
                    changed = true;
                    break search;
                }
            }   
        }
    }

    return convGrammar(grammar.\start, productions);
}

rel[Symbol, ConvProd] replaceSymbol(rel[Symbol, ConvProd] prods, Symbol replaceSym, Symbol replaceBySym) {
    replaceByProds = prods[replaceBySym];
    combined = combineEqual(replaceByProds, replaceBySym, {replaceSym, replaceBySym});

    filteredProds = {p | p:<def, _> <- prods, def != replaceSym && def != replaceBySym};
    replacedProds = {
        <def, convProd(
            lDef, 
            [   symb(sym, scopes) := p 
                    ? getWithoutLabel(sym) == replaceSym 
                        ? symb(copyLabel(sym, replaceBySym), scopes) 
                        : p 
                    : p
                | p <- parts], 
            sources)>
        | <def, convProd(lDef, parts, sources)> <- filteredProds
    };

    return replacedProds + {<replaceBySym, prod> | prod <- combined};
}

set[ConvProd] combineEqual(set[ConvProd] prods, Symbol targetSym, set[Symbol] equalSyms) 
    = {
        convProd(
            copyLabel(def, targetSym), 
            combineConsecutive(replaceSymbols(parts, equalSyms, targetSym, true)),
            sources
        ) 
        | convProd(def, parts, sources) <- prods
    };

bool areEquivalent(Symbol a, set[ConvProd] prodsA, Symbol b, set[ConvProd] prodsB)
    = equals(prodsA, prodsB, {a, b});