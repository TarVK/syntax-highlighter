module specTransformations::GrammarTransformer

import conversion::conversionGrammar::ConversionGrammar;
import Logging;

@doc {
    Transforms the given conversion grammar
}
alias GrammarTransformer = ConversionGrammar(ConversionGrammar grammar, Logger log);

