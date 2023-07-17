@synopsis{PSNFA tools for analyzing properties}
@description{
    Utilities to determine partial overlap between different PSNFA languages
}

module regex::PSNFATools

import regex::Regex;
import regex::RegexToPSNFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFA;

@doc {
    Computes a PSNFA that accepts all tuples (p, w, s), such that 
    ∃ ph,pt,sh,st ∈ E* . phpt=p ∧ shst=s ∧ (ph, ptw, s) ∈ L(head) ∧ (ph, pt, ws) ∈ L(head) ∧ (p, wsh, st) ∈ L(tail)

    I.e. words that can both be the end of a match of head and also the beginning of a match of tail, while considering prefixes and suffixes
}
NFA[State] getConcatOverlapPSNFA(NFA[State] head, NFA[State] tail){
    // TODO: ...
    return ();
}

@doc {
    Computes a PSNFA that accepts all tuples (p, w, s), for which
    ∃ ph ∈ E*, pt ∈ E+. pspt = p ∧ (ph, ptw, s) ∈ L(n)

    I.e. words that are valid extensions of other words that are already accepted
}
NFA[State] getExtensionPSNFA(NFA[State] n) {
    // TODO: ...
    return ();
}

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