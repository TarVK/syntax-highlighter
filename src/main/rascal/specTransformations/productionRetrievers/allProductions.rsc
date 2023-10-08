module specTransformations::productionRetrievers::allProductions

import specTransformations::productionRetrievers::ProductionRetriever;
import conversion::conversionGrammar::ConversionGrammar;

@doc {
    A production retriever that simply returns all productions of the grammar
}
public ProductionRetriever allProductions 
    = set[ConvProd](ConversionGrammar grammar) {
        return grammar.productions<1>;
    };