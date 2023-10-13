module specTransformations::tokenAugmenters::addKeywordTokens

import conversion::conversionGrammar::ConversionGrammar;
import specTransformations::tokenAugmenters::addTokens;
import specTransformations::productionRetrievers::ProductionRetriever;
import specTransformations::GrammarTransformer;
import regex::Regex;
import Logging;

@doc {
    Adds tokens for keyword expressions
}
GrammarTransformer addKeywordTokens(ProductionRetriever productions) 
    = addTokens(productions, parseRegexReduced("[a-zA-Z]{2,}"), "keyword", "keyword");