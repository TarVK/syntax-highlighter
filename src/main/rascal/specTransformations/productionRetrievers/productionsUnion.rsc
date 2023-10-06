module specTransformations::productionRetrievers::allProductions

import specTransformations::productionRetrievers::ProductionRetriever;
import conversion::conversionGrammar::ConversionGrammar;

@doc {
    A production retriever that combines all productions of other retrievers
}
ProductionRetriever productionsUnion(set[ProductionRetriever] retrievers) 
    = set[ConvProd] (ConversionGrammar grammar) {
        return {*retriever(grammar) | retriever <- retrievers};
    };