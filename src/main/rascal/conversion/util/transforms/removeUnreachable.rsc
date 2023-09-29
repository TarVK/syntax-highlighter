module conversion::util::transforms::removeUnreachable

import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::BaseNFA;


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

@doc {
    Retrieves all symbols that are reachable in the grammar

    If includeSources is set to true, it also includes paths that pass through symbol definitions, rather than productions
}
set[Symbol] getReachableSymbols(ConversionGrammar grammar, bool includeSources) {
    set[Symbol] reachable = {grammar.\start};
    set[Symbol] added = reachable;

    while(size(added)>0) {
        set[Symbol] newAdded = {};

        for(
            convProd(_, parts) <- grammar.productions[added],
            ref(refSym, _, _) <- parts,
            refSym notin reachable
        ) {
            reachable += refSym;
            newAdded += refSym;
        }

        if(includeSources){
            newSourceReachable = expandSources(added) - reachable;
            reachable += newSourceReachable;
            newAdded += newSourceReachable;
        }

        added = newAdded;
    }

    return reachable;
}

@doc {
    Expands what can be reached from custom symbol sources, but not necessarily through productions
}
set[Symbol] expandSources(set[Symbol] symbols) {
    set[Symbol] sourceReachable = {};
    for(sym <- symbols) {
        if(unionRec(syms, _) := sym) sourceReachable += syms;
        if(unionRec(syms, n) := sym, n != emptyNFA) sourceReachable += unionRec(syms, emptyNFA);
        if(closed(s, c) := sym) sourceReachable += {s, c};
    }
    return sourceReachable;
}