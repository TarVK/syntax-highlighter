module conversionGrammar::determinism::checkExtensionOverlap

import util::Maybe;

import conversionGrammar::ConversionGrammar;
import conversionGrammar::RegexCache;
import regex::Regex;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::PSNFATools;
import regex::util::charClass;
import regex::NFASimplification;

@doc {
    Checks whether a given regular expression re has multiple length matches starting with the same prefix, for which one may lead to a correct parse while the other doesn't. Returns a NFA matching the longer matches for which a shorter prefix also exists, if such cases exist.

    Note that we don't have to check whether multiple different tokenizations for the same words exist in this regex, because under the assumption that the input grammar is unambiguous, this can't happen. 
    Overlap between matches can still happen however, since this does not necessarily cause ambiguity if the following symbols make it so only one of them is valid.  E.g. `/(some|something)/` followed by `/thing/` is not ambiguous and can only match in one way. But when encountering "something" by itself, the first regex choosing alternative "something" would be wrong. and not allow for a valid total match. Hence this grammar wouldn't be deterministic.  
}
Maybe[NFA[State]] checkExtensionOverlap(Regex re) {
    nfa = regexToPSNFA(re);

    // The language followed by any non-empty word
    extension = getExtensionNFA(concatPSNFA(nfa, charPSNFA(anyCharClass())));
    
    overlap = productPSNFA(nfa, extension);
    if(!isEmpty(overlap)) {
        simplified = relabelSetPSNFA(minimize(overlap));
        return just(simplified);
    }
    return nothing();
}