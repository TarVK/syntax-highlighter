module regex::RegexToPSNFA

import IO;

import regex::RegexTypes;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFATypes;
import regex::PSNFACombinators;
import regex::NFASimplification;
import regex::PSNFASimplification;

// Would prefer to not import this here, see if we can get around this
import conversion::util::RegexCache;

@doc {
    Converts the given regex to a NFA with an equivalent language

    Assumes the regex to be reduced
}
NFA[State] regexToPSNFA(Regex regex) {
    NFA[State] n = neverPSNFA();
    switch(regex) {
        case never(): n = neverPSNFA();
        case Regex::empty(): n = emptyPSNFA();
        case always(): n = alwaysPSNFA();
        case character(cc): n = charPSNFA(cc);
        case lookahead(r, la): n = lookaheadPSNFA(regexToPSNFA(r), regexToPSNFA(la));
        case lookbehind(r, lb): n = lookbehindPSNFA(regexToPSNFA(r), regexToPSNFA(lb));
        case \negative-lookahead(r, la): n = negativeLookaheadPSNFA(regexToPSNFA(r), regexToPSNFA(la));
        case \negative-lookbehind(r, lb): n = negativeLookbehindPSNFA(regexToPSNFA(r), regexToPSNFA(lb));
        case concatenation(h, t): n = concatPSNFA(regexToPSNFA(h), regexToPSNFA(t));
        case alternation(r1, r2): n = unionPSNFA(regexToPSNFA(r1), regexToPSNFA(r2));
        case subtract(r, s): n = strongSubtractPSNFA(regexToPSNFA(r), regexToPSNFA(s));
        case mark(t, r): return tagsPSNFA(regexToPSNFA(r), t);
        case \multi-iteration(r): {
            rnfa = regexToPSNFA(r);
            rdfa = removeUnreachable(relabelSetPSNFA(convertPSNFAtoDFA(rnfa, {})));
            n = iterationPSNFA(rdfa);
        }
        default: throw "Unsupported regex: <regex>";
    }

    simplified = simplify(n);
    return simplified;
}

NFA[State] simplify(NFA[State] n) {
    return minimizeUnique(n);
}
