module conversion::shapeConversion::util::overlapsAlternation

import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;
import regex::RegexToPSNFA;
import regex::PSNFACombinators;
import regex::NFA;

@doc {
    Checks whether a given regular expression overlaps any of the regular expressions of alternations of a given symbol
}
bool overlapsProduction(Symbol ref, Regex r, ConversionGrammar grammar) {
    prods = grammar.productions[ref];
    for(convProd(_, [regexp(r2), *_], _) <- prods) {
        n = regexToPSNFA(r);
        n2 = regexToPSNFA(r2);
        inter = productPSNFA(n, n2, true);
        if(!isEmpty(inter)) return true;
    }
    return false;
}