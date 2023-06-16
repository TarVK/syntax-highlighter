module regex::RegexToPSNFA

import regex::Regex;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFASimplification;

@doc {
    Converts the given regex to a NFA with an equivalent language

    Assumes the regex to be reduced
}
NFA[State] regexToPSNFA(Regex regex) {
    NFA[State] n = neverPSNFA();
    switch(regex) {
        case never(): n = neverPSNFA();
        case empty(): n = emptyPSNFA();
        case always(): n = alwaysPSNFA();
        case character(cc): n = charPSNFA(cc);
        case lookahead(r, la): n = lookaheadPSNFA(regexToPSNFA(r), regexToPSNFA(la));
        case lookbehind(r, lb): n = lookbehindPSNFA(regexToPSNFA(r), regexToPSNFA(lb));
        case \negative-lookahead(r, la): n = negativeLookaheadPSNFA(regexToPSNFA(r), regexToPSNFA(la));
        case \negative-lookbehind(r, lb): n = negativeLookbehindPSNFA(regexToPSNFA(r), regexToPSNFA(lb));
        case concatenation(h, t): n = concatPSNFA(regexToPSNFA(h), regexToPSNFA(t));
        case alternation(r1, r2): n = unionPSNFA(regexToPSNFA(r1), regexToPSNFA(r2));
        case subtract(r, s): n = subtractPSNFA(regexToPSNFA(r), regexToPSNFA(s));
        case scoped(n, r): return regexToPSNFA(r);
        case \multi-iteration(r): {
            rnfa = regexToPSNFA(r);
            rdfa = removeUnreachable(relabelSetPSNFA(convertPSNFAtoDFA(rnfa)));
            n = iterationPSNFA(rdfa);
        }
        case cached(psnfa, exp): return psnfa;
    }

    return simplify(n);
}

NFA[State] simplify(NFA[State] n) {
    simplified = removeDuplicates(removeEpsilon(removeUnreachable(n)));
    // simplified = removeEpsilon(removeUnreachable(n));
    return relabelIntPSNFA(relabel(simplified));
    // return mapStates(simplified, State (set[set[State]] states) {
    //     return stateSet({*S | S <- states});
    // });
}


data Regex = cached(NFA[State] psnfa, Regex exp);
str stringify(cached(psnfa, exp)) = stringify(exp);

@doc {
    Retrieves the PSNFA of the given regular expression, and the regular expression with the PSNFA cached into it for quick access later (using this same function)
}
tuple[Regex, NFA[state]] cachedRegexToPSNFA(Regex regex) {
    if (cached(nfa, exp) := regex) return <regex, nfa>;

    nfa = regexToPSNFA(regex);
    return <cached(nfa, regex), nfa>;
}
