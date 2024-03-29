module conversion::util::equality::deduplicateSymbols

import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::util::meta::LabelTools;
import conversion::util::equality::getEquivalentSymbols;

data DedupeType = keep() | replace() | reference();

@doc {
    Deduplicates symbols by detecting production sets that are homomorphic, and removing these duplicates.
    This can be done by replacing the symbol fully, or keeping a reference to the symbol, but make it a alias for another symbol by directly referencing it
}
ConversionGrammar deduplicateSymbols(
    ConversionGrammar grammar, 
    Symbol(Symbol, Symbol) prioritize,
    DedupeType(Symbol) dedupeBehavior,
    bool(Symbol, Symbol, ClassMap) equals
) {
    rel[Symbol, ConvProd] productions = grammar.productions;

    classes = getEquivalentSymbols(grammar, equals);
    
    for(class <- classes) {
        // Filter out any aliases
        class = {sym | sym <- class, !isAlias(sym, grammar)};

        if({sym, *eqSyms} := class, size(eqSyms)>0) {
            for(otherSym <- eqSyms) 
                sym = prioritize(sym, otherSym);

            eqSyms = class - {sym};

            replaceSyms = {rSym | rSym <- eqSyms, dedupeBehavior(rSym)==replace()};
            for(replaceSym <- replaceSyms)
                productions = replaceSymbol(productions, replaceSym, sym);

            referenceSyms = {rSym | rSym <- eqSyms, dedupeBehavior(rSym)==reference()};
            for(referenceSym <- referenceSyms) {
                if(getWithoutLabel(referenceSym) == getWithoutLabel(sym))
                    throw referenceSym;
                productions = referenceSymbol(productions, referenceSym, sym);
            }
            
        }
    }
    return convGrammar(grammar.\start, productions);
}

rel[Symbol, ConvProd] referenceSymbol(rel[Symbol, ConvProd] prods, Symbol replaceSym, Symbol replaceBySym) {
    filteredProds = {p | p:<def, _> <- prods, def != replaceSym};
    newProd = <replaceSym, convProd(replaceSym, [ref(replaceBySym, [], {})])>;


    return filteredProds + newProd;
}

rel[Symbol, ConvProd] replaceSymbol(rel[Symbol, ConvProd] prods, Symbol replaceSym, Symbol replaceBySym) {
    filteredProds = {p | p:<def, _> <- prods, def != replaceSym};
    replacedProds = {
        <def, convProd(lDef, [   
            ref(sym, scopes, sources) := p && getWithoutLabel(sym) == replaceSym 
                ? ref(copyLabel(sym, replaceBySym), scopes, sources) 
                : p 
            | p <- parts
        ])>
        | <def, convProd(lDef, parts)> <- filteredProds
    };

    return replacedProds;
}