module specTransformations::productionRetrievers::exceptKeywordsProductions

import specTransformations::productionRetrievers::ProductionRetriever;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;

@doc {
    A production retriever that removes all keyword symbol productions
}
ProductionRetriever exceptKeywordsProductions(ProductionRetriever retriever) 
    = set[ConvProd] (ConversionGrammar grammar) {
        return { 
            p 
            | p:convProd(lDef, _) <- retriever(grammar),
            keywords(_) !:= getWithoutLabel(lDef)
        };
    };