module conversion::util::removeUnreachable

import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;


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

            if(includeSources){
                set[Symbol] sourceReachable = {};
                if(unionRec(syms) := refSym) sourceReachable = syms;
                if(closed(s, c) := refSym) sourceReachable = {s, c};

                if(sourceReachable != {}){
                    sourceReachable = sourceReachable - reachable;
                    reachable += sourceReachable;
                    newAdded += sourceReachable;
                }
            }
        }

        added = newAdded;
    }

    return reachable;
}