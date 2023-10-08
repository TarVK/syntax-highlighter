module determinism::util::getAlternations

import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;

@doc {
    Retrieves all alternation regexes for a given symbol of the grammar
}
rel[Regex, ConvProd] getAlternations(ConversionGrammar grammar, Symbol sym) 
    = {<r, p> | p:convProd(_, [regexp(r), *_]) <- grammar.productions[sym]};