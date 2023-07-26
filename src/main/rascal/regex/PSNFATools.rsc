@synopsis{PSNFA tools for analyzing properties}
@description{
    Utilities to determine partial overlap between different PSNFA languages
}

module regex::PSNFATools

import IO;
import util::Maybe;

import regex::Regex;
import regex::RegexToPSNFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFA;

// Would prefer to not import this here, see if we can get around this
import conversionGrammar::RegexCache;

@doc {
    Checks whether the two given NFAs define the same language
}
bool equals(NFA[State] a, NFA[State] b) {
    if (a == b) return true;
    
    inANotB = subtractPSNFA(a, b);
    inBNotA = subtractPSNFA(b, a);
    return isEmpty(inANotB) && isEmpty(inBNotA);
}

@doc {
    Checks whether two given regular expressions define the same language
}
bool equals(Regex a, Regex b) {
    aNFA = regexToPSNFA(a);
    bNFA = regexToPSNFA(b);
    return equals(aNFA, bNFA);
}

@doc {
    Computes the difference between the two PSNFAs, which includes all words in one and not the other
}
NFA[State] differencePSNFA(NFA[State] a, NFA[State] b) {
    if (a == b) return neverPSNFA();
    
    inANotB = subtractPSNFA(a, b);
    inBNotA = subtractPSNFA(b, a);
    return unionPSNFA(inANotB, inBNotA);
}

@doc {
    Creates a NFA that accepts all the original words, as well as any extensions of those words
}
NFA[State] getExtensionNFA(NFA[State] n) = concatPSNFA(n, alwaysPSNFA());

@doc {
    Obtains PSNFAs o and e such that,
    L(no) = {(p, w, s) | (p, w, s) ∈ L(n) ∧ (∃ wp, ws . w = wp ws ∧ (p, wp, ws s) ∈ L(m))}
    L(me) = {(p, w, s) | ∃ (mp, mw, ms) ∈ L(m) . p = mp mw ∧ w s = ms ∧ (mp, mw w, s) ∈ L(n)}

    I.e. no specifies all words in n, such that m contains a prefix of said word,
    and me specifies all extension words t such that there exists a word h in m for which the concatenation ht is in n (a word in m can be extended using e to be part of n). 

    If these languages are empty, nothing is returned instead
}
Maybe[tuple[NFA[State] no, NFA[State] me]] getPrefixOverlap(NFA[State] n, NFA[State] m) {
    // TODO: implement
}