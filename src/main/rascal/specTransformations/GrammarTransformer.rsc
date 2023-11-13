module specTransformations::GrammarTransformer

import conversion::conversionGrammar::ConversionGrammar;
import Logging;

@doc {
    Transforms the given conversion grammar
}
alias GrammarTransformer = ConversionGrammar (ConversionGrammar grammar, Logger log);

@doc {
    A dummy transformer that does not apply any transformations
}
public GrammarTransformer transformerIdentity = ConversionGrammar (ConversionGrammar g, Logger l) {return g;};