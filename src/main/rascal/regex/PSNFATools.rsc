@synopsis{PSNFA tools for analyzing properties}
@description{
    Utilities to determine partial overlap between different PSNFA languages
}

module regex::PSNFATools

import regex::PSNFA;

@doc {
    Computes a PSNFA that accepts all tuples (p, w, s), such that 
    ∃ ph,pt,sh,st ∈ E* . phpt=p ∧ shst=s ∧ (ph, ptw, s) ∈ L(head) ∧ (ph, pt, ws) ∈ L(head) ∧ (p, wsh, st) ∈ L(tail)

    I.e. words that can both be the end of a match of head and also the beginning of a match of tail, while considering prefixes and suffixes
}
NFA[State]  getConcatOverlapPSNFA(NFA[State] head, NFA[State] tail){

}

@doc {
    Computes a PSNFA that accepts all tuples (p, w, s), for which
    ∃ ph ∈ E*, pt ∈ E+. pspt = p ∧ (ph, ptw, s) ∈ L(n)

    I.e. words that are valid extensions of other words that are already accepted
}
NFA[State] getExtensionPSNFA(NFA[State] n) {

}