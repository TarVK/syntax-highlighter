module conversion::shapeConversion::deduplicateProductions

import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
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
    combined = combineEqual(replaceByProds, replaceBySym, {replaceSym, replaceBySym}, true);

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

set[ConvProd] combineEqual(set[ConvProd] prods, Symbol targetSym, set[Symbol] equalSyms, bool keepLabel) {
    list[ConvSymbol] subParts(list[ConvSymbol] parts) {
        Maybe[ConvSymbol] last = nothing();
        list[ConvSymbol] out = [];
        for(part <- parts) {
            if(symb(sym, scopes) := part) {
                pureSym = getWithoutLabel(sym);
                if(pureSym in equalSyms) 
                    part = symb(keepLabel ? copyLabel(sym, targetSym) : targetSym, scopes);

                if(just(part) !:= last) 
                    out += part;

                last = just(part);
            } else {
                last = just(part);
                out += part;
            }
        }
        return out;
    }

    return {
        convProd(keepLabel ? copyLabel(def, targetSym) : targetSym, subParts(parts), sources) 
        | convProd(def, parts, sources) <- prods
    };
}

bool areEquivalent(Symbol a, set[ConvProd] prodsA, Symbol b, set[ConvProd] prodsB) {
    set[ConvProd] removeSources(set[ConvProd] prods) 
        = {convProd(d, p, {}) | convProd(d, p, _) <- prods};

    subbedA = (combineEqual(prodsA, a, {a, b}, false));
    subbedB = (combineEqual(prodsB, a, {a, b}, false));

    return subbedA == subbedB;
}