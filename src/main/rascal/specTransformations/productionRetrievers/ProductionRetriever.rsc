module specTransformations::productionRetrievers::ProductionRetriever

import conversion::conversionGrammar::ConversionGrammar;

@doc {
    A function to retrieve productions from the grammar
}
alias ProductionRetriever = set[ConvProd] (ConversionGrammar grammar);