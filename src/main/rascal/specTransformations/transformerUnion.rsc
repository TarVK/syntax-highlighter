module specTransformations::transformerUnion

import conversion::conversionGrammar::ConversionGrammar;
import specTransformations::GrammarTransformer;
import Logging;

@doc {
    Creates a union of the given transformers, applying the transformers in sequence
}
GrammarTransformer transformerUnion(list[GrammarTransformer] transformers)
    = ConversionGrammar(ConversionGrammar grammar, Logger log) {
        for(transform <- transformers)
            grammar = transform(grammar, log);
        return grammar;
    };