module conversion::determinism::improveExtensionOverlap

import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::determinism::expandSymbols;
import conversion::util::RegexCache;
import regex::Regex;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::PSNFATools;
import regex::util::charClass;
import regex::NFASimplification;

@doc {
    Checks whether a given regular expression prod has multiple length matches starting with the same prefix, for which one may lead to a correct parse while the other doesn't. Returns a NFA matching the longer matches for which a shorter prefix also exists, if such cases exist.

    Note that we don't have to check whether multiple different tokenizations for the same words exist in this regex, because under the assumption that the input grammar is unambiguous, this can't happen. 
    Overlap between matches can still happen however, since this does not necessarily cause ambiguity if the following symbols make it so only one of them is valid.  E.g. `/(some|something)/` followed by `/thing/` is not ambiguous and can only match in one way. But when encountering "something" by itself, the first regex choosing alternative "something" would be wrong. and not allow for a valid total match. Hence this grammar wouldn't be deterministic.  
}
tuple[
    // The new expression (which may be identical to the old)
    Regex, 
    // The unresolved overlap if any
    Maybe[NFA[State]], 
    // THe expansion depth to fix overlap, if any
    Maybe[int]
] improveExtensionOverlap(Regex re, list[ConvSymbol] follow,  ConversionGrammar grammar, int maxLookaheadLength) {
    if(just(overlap) := doesSelfOverlap(re)) {
        if(just(<fixedRe, fixLength>) := fixOverlap(re, follow, grammar, maxLookaheadLength)) {
            return <fixedRe, nothing(), just(fixLength)>;
        } else {
            simplified = minimizeUnique(overlap);
            return <re, just(simplified), nothing()>;
        }
    }

    return <re, nothing(), nothing()>;
}

Maybe[tuple[Regex, int]] fixOverlap(Regex re, list[ConvSymbol] parts, ConversionGrammar grammar, int maxLength) {
    for(length <- [1..maxLength+1]) {
        expansion = expandSymbolsToRegex(parts, grammar, length);
        if(just(expansionRegex) := expansion) {
            expanded = getCachedRegex(lookahead(re, mark({determinismTag()}, expansionRegex)));

            if(nothing() := doesSelfOverlap(expanded))
                return just(<expanded, length>);
        }
    }
    return nothing();
}

Maybe[NFA[State]] doesSelfOverlap(Regex re) {
    nfa = regexToPSNFA(re);

    // The language followed by any non-empty word
    extension = getExtensionNFA(concatPSNFA(nfa, charPSNFA(anyCharClass())));
    
    overlap = productPSNFA(nfa, extension, true);
    if(!isEmpty(overlap)) 
        return just(overlap);
    return nothing();
}