module specTransformations::tokenAugmenters::addOperatorTokens

import conversion::conversionGrammar::ConversionGrammar;
import specTransformations::tokenAugmenters::addTokens;
import specTransformations::productionRetrievers::ProductionRetriever;
import specTransformations::GrammarTransformer;
import regex::Regex;
import Logging;

@doc {
    Adds tokens for common operator expressions 
}
GrammarTransformer addOperatorTokens(ProductionRetriever productions) 
    = addTokens(productions, parseRegexReduced("[\\-+=\\\\/*&%$#@!?\>\<|~^]+"), "keyword.operator", "operator");