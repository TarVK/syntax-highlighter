module specTransformations::productionRetrievers::symbolDescendentProductions

import specTransformations::productionRetrievers::ProductionRetriever;
import specTransformations::productionRetrievers::symbolProductions;
import conversion::conversionGrammar::ConversionGrammar;

@doc {
    A production retriever that combines all productions of other retrievers
}
ProductionRetriever symbolDescendentProductions(Symbol symbol) 
    = symbolProductions({symbol});
ProductionRetriever symbolDescendentProductions(set[Symbol] symbols) 
    = set[ConvProd] (ConversionGrammar grammar) {
        return symbolProductions(getSymbolsReachableFrom(grammar, symbols))(grammar);
    };

    
@doc {
    Retrieves all symbols that are reachable from the given starts in the grammar
}
set[Symbol] getSymbolsReachableFrom(ConversionGrammar grammar, set[Symbol] starts) {
    set[Symbol] reachable = starts;
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
        added = newAdded;
    }

    return reachable;
}