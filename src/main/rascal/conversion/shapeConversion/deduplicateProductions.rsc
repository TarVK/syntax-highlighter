module conversion::shapeConversion::deduplicateProductions

import Set;
import util::Maybe;
import Relation;
import Map;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::util::getComparisonProds;
import conversion::shapeConversion::util::compareProds;
import conversion::util::RegexCache;

@doc {
    Deduplicates productions by detecting productions that are homomorphic and removing these duplicates.
    It also removes duplicate productions within the same symbol.
    Assumes all rules in the grammar to be right-recursive, or an empty production
}
ConversionGrammar deduplicateProductions(ConversionGrammar grammar) 
    = deduplicateProductions(
        grammar,
        Symbol(Symbol a, Symbol b) {
            if(grammar.\start == a) return a;
            return b;
        },
        DedupeType(Symbol) { return reference(); }
    );

data DedupeType = keep() | replace() | reference();
ConversionGrammar deduplicateProductions(
    ConversionGrammar grammar,
    Symbol(Symbol, Symbol) prioritize,
    DedupeType(Symbol) dedupeBehavior
) {
    rel[Symbol, ConvProd] productions = grammar.productions;

    println("calc-classes");
    classes = getEquivalentSymbols(grammar);
    println("start-dedup");
    
    for(class <- classes) {
        // Filter out any aliases
        class = {sym | sym <- class, {convProd(_, [symb(_, _)], _)} !:= productions[sym]};

        if({sym, *eqSyms} := class, size(eqSyms)>0) {
            for(otherSym <- eqSyms) 
                sym = prioritize(sym, otherSym);

            eqSyms = class - {sym};
            productions = combineEqualSyms(productions, sym, eqSyms);

            replaceSyms = {rSym | rSym <- eqSyms, dedupeBehavior(rSym)==replace()};
            for(replaceSym <- replaceSyms)
                productions = replaceSymbol(productions, replaceSym, sym);

            referenceSyms = {rSym | rSym <- eqSyms, dedupeBehavior(rSym)==reference()};
            for(referenceSym <- referenceSyms)
                productions = referenceSymbol(productions, referenceSym, sym);
        }
    }

    println("start-self-dedup");
    ProdMap prodMap = index(productions);
    prodMap = removeDuplicateProds(prodMap, getClassMap(classes));

    println("end-dedup");
    return convGrammar(grammar.\start, toRel(prodMap));
}


rel[Symbol, ConvProd] combineEqualSyms(rel[Symbol, ConvProd] prods, Symbol replaceBySym, set[Symbol] equalSyms) {
    filteredProds = {p | p:<def, _> <- prods, def != replaceBySym};

    replaceByProds = prods[replaceBySym];
    combined = combineEqual(replaceByProds, replaceBySym, equalSyms);
    newProds = {<replaceBySym, prod> | prod <- combined};

    return filteredProds + newProds;
}

rel[Symbol, ConvProd] referenceSymbol(rel[Symbol, ConvProd] prods, Symbol replaceSym, Symbol replaceBySym) {
    filteredProds = {p | p:<def, _> <- prods, def != replaceSym};
    newProd = <replaceSym, convProd(replaceSym, [symb(replaceBySym, [])], {})>;

    return filteredProds + newProd;
}

rel[Symbol, ConvProd] replaceSymbol(rel[Symbol, ConvProd] prods, Symbol replaceSym, Symbol replaceBySym) {
    filteredProds = {p | p:<def, _> <- prods, def != replaceSym};
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

    return replacedProds;
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

ProdMap removeDuplicateProds(ProdMap prods, ClassMap classMap) {
    for(sym <- prods) {
        set[ConvProd] newSymProds = {};

        symProds = [*prods[sym]];
        for(i <- [0..size(symProds)]) {
            prod1 = symProds[i];
            
            hasDuplicate = any(prod2 <- symProds[i+1..], prodsEqual(prod1, prod2, classMap, true));
            if(!hasDuplicate)
                newSymProds += prod1;
        }

        prods[sym] = newSymProds;
    }

    return prods;
}