module regex::RegexToPSNFA

import IO;
import regex::RegexTypes;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFATypes;
import regex::PSNFACombinators;
import regex::NFASimplification;

// Would prefer to not import this here, see if we can get around this
import conversionGrammar::RegexCache;

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
    // println("-1");
    // simplified1 = removeUnreachable(n);
    // println("-2");
    // simplified2 = removeEpsilon(simplified1);
    // println("-3");
    // simplified3 = removeDuplicates(simplified2);
    // println("-4");

    // // simplified = removeDuplicates(removeEpsilon(removeUnreachable(n)));
    // // simplified = removeEpsilon(removeUnreachable(n));
    // return relabelIntPSNFA(relabel(simplified3));
    // return mapStates(simplified, State (set[set[State]] states) {
    //     return stateSet({*S | S <- states});
    // });

    // simplified = minimize(removeUnreachable(n));
    simplified = minimize(n);
    return relabelIntPSNFA(relabel(simplified));
}
