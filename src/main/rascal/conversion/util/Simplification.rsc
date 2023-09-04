module conversion::util::Simplification

import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::customSymbols;

@doc {
    Removes all symbols in the grammar that are no longer reachable

    keepSources should be set to true to keep sources of unionRecs around, even if not referenced directly. 
}
ConversionGrammar removeUnreachable(ConversionGrammar grammar)
    = removeUnreachable(grammar, false);
ConversionGrammar removeUnreachable(ConversionGrammar grammar, bool keepSources) {
    reachable = getReachableSymbols(grammar, keepSources);
    grammar.productions = {
        <sym, p> 
        | <sym, p> <- grammar.productions,
        sym in reachable
    };
    return grammar;
}
set[Symbol] getReachableSymbols(ConversionGrammar grammar, bool includeSources) {
    set[Symbol] reachable = {grammar.\start};
    set[Symbol] added = reachable;

    while(size(added)>0) {
        set[Symbol] newAdded = {};
        for(
            convProd(_, parts, _) <- grammar.productions[added],
            symb(ref, _) <- parts,
            ref notin reachable
        ) {
            reachable += ref;
            newAdded += ref;

            if(includeSources && unionRec(syms) := ref) {
                syms = syms - reachable;
                reachable += syms;
                newAdded += syms;
            }
        }

        added = newAdded;
    }

    return reachable;
}

@doc {
    Removes all aliases in the grammar and replaces them by its definition 
}
ConversionGrammar removeAliases(ConversionGrammar grammar) {
    aliases = getAliases(grammar);

    // Remove alias definitions
    aliasSyms = aliases<0>;
    grammar.productions = {
        <sym, p> 
        | <sym, p> <- grammar.productions,
        sym notin aliasSyms
    };

    // Replace alias references
    for(<aliasSym, sym> <- aliases) 
        grammar = replaceSymbol(aliasSym, sym, grammar);

    return grammar;
}

rel[Symbol, Symbol] getAliases(ConversionGrammar grammar) {
    syms = grammar.productions<0>;
    rel[Symbol, Symbol] aliases = {
        <aliasSym, followAliases(aliasSym, grammar)>
        | aliasSym <- syms
    };
    aliases -= {<sym, sym> | sym <- syms};
    return aliases;
}
Symbol followAliases(Symbol sym, ConversionGrammar grammar) {
    while({convProd(_, [symb(ref, _)], _)} := grammar.productions[sym]) {
        sym = getWithoutLabel(ref);
    }
    return sym;
}

@doc {
    Renames the generated symbols to simple sort names
}
ConversionGrammar relabelGenerated(ConversionGrammar grammar) {
    set[Symbol] generated = {
        sym 
        | sym <- grammar.productions<0>,
        unionRec(_) := sym || seq(_) := sym
    };

    int i=0;
    for(sym <- generated) {
        Symbol rSym = sort("G<i>");
        while(size(grammar.productions[rSym])>0){
            i += 1;
            rSym = sort("G<i>");
        }

        grammar = renameSymbol(sym, rSym, grammar);
        i += 1;
    }

    return grammar;
}