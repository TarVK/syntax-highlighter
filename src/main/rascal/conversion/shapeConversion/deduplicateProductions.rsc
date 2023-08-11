module conversion::shapeConversion::deduplicateProductions

import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::util::getComparisonProds;
import conversion::shapeConversion::util::compareProds;
import conversion::util::RegexCache;

@doc {
    Deduplicates productions by detecting productions that are homomorphic and removing these duplicates.
    Assumes all rules in the grammar to be right-recursive, or an empty production
}
ConversionGrammar deduplicateProductions(ConversionGrammar grammar) {
    rel[Symbol, ConvProd] productions = grammar.productions;

    classes = getEquivalentSymbols(grammar);
    for(class <- classes) {
        if({sym, *eqSyms} := class, grammar.\start notin eqSyms) {
            for(replaceSym <- eqSyms)
                productions = replaceSymbol(productions, replaceSym, sym);
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