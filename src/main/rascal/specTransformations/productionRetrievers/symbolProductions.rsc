module specTransformations::productionRetrievers::symbolProductions

import specTransformations::productionRetrievers::ProductionRetriever;
import conversion::conversionGrammar::ConversionGrammar;

@doc {
    A production retriever that combines all productions of other retrievers
}
ProductionRetriever symbolProductions(Symbol symbol) 
    = symbolProductions({symbol});
ProductionRetriever symbolProductions(set[Symbol] symbols) 
    = set[ConvProd] (ConversionGrammar grammar) {
        return grammar.productions[symbols];
    };