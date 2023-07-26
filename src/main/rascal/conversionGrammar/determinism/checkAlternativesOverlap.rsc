module conversionGrammar::determinism::checkAlternativesOverlap

import util::List;
import conversionGrammar::ConversionGrammar;
import regex::PSNFA;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::NFASimplification;
import conversionGrammar::RegexCache;

alias ProdsOverlaps = set[ProdsOverlap];
alias ProdsOverlap = tuple[
    // The NFA encoding words accepted by the prefix regex of the first production, for which a prefix of the word is accepted by the prefix regex of the second production
    NFA[State], 
    // The first production which has overlap with another
    ConvProd, 
    // The second production which has overlap with another
    ConvProd
];


@doc {
    Computes overlap between the prefix (first regular expression) of every pair of the given productions.
    Returns a set of non-empty NFAs that encode the overlap between prefixes, where each word in the language is accepted by one regex and a prefix of it is accepted by the other. 
}
ProdsOverlaps checkAlternativesOverlap(set[ConvProd] prods) 
    = checkAlternativesOverlap([p | p <- prods]);
ProdsOverlaps checkAlternativesOverlap(list[ConvProd] prods) {
    ProdsOverlaps out = {};
    for(<a:convProd(_, [regexp(ra), *_], _), b:convProd(_, [regexp(rb), *_], _)> <- prods * prods) {
        if(a==b) continue;
        nfaA = regexToPSNFA(ra);
        nfaB = regexToPSNFA(rb);
        extensionA = getExtensionNFA(nfaA);
        overlap = productPSNFA(nfaB, extensionA, true);
        if(!isEmpty(overlap)){
            simplified = relabelSetPSNFA(minimize(overlap));
            out += <simplified, a, b>;

            // TODO: attempt to fix alternatives overlap using negative lookaheads. This first requires me to have a PSNFA->regex conversion algorithm however. 
        }
    }
    return out;
}