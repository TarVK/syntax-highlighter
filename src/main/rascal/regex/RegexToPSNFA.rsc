module regex::regexToPSNFA

import IO;

import regex::RegexTypes;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFATypes;
import regex::PSNFACombinators;
import regex::NFASimplification;
import regex::PSNFASimplification;

// @doc {
//     Converts the given regex to a NFA with an equivalent language, if shouldSimplify is set to true, it ensures the NFA to uniquely represent this language.

//     Assumes the regex to be reduced
// }
// NFA[State] regexToPSNFA(Regex regex) 
//     = regexToPSNFA(regex, true);
// NFA[State] regexToPSNFA(Regex regex, bool shouldSimplify) {
//     if(meta(r, cacheMeta(nfa, _)) := regex) return nfa;

//     n = regexToPSNFANonUnique(regex, shouldSimplify);
//     return shouldSimplify ? minimizeUnique(n) : n;
// }


// @doc {
//     Converts the given regex to a NFA with an equivalent language

//     Assumes the regex to be reduced
// }
// NFA[State] regexToPSNFANonUnique(Regex regex, bool shouldSimplify) {
//     NFA[State] rec(Regex r) = regexToPSNFANonUnique(r, shouldSimplify);

//     NFA[State] n;
//     switch(regex) {
//         case never(): n = neverPSNFA();
//         case Regex::empty(): n = emptyPSNFA();
//         case always(): n = alwaysPSNFA();
//         case character(cc): n = charPSNFA(cc);
//         case lookahead(r, la): n = lookaheadPSNFA(rec(r), rec(la));
//         case lookbehind(r, lb): n = lookbehindPSNFA(rec(r), rec(lb));
//         case \negative-lookahead(r, la): n = negativeLookaheadPSNFA(rec(r), rec(la));
//         case \negative-lookbehind(r, lb): n = negativeLookbehindPSNFA(rec(r), rec(lb));
//         case concatenation(h, t): n = concatPSNFA(rec(h), rec(t));
//         case alternation(r1, r2): n = unionPSNFA(rec(r1), rec(r2));
//         case subtract(r, s): n = strongSubtractPSNFA(rec(r), rec(s));
//         case mark(t, r): return tagsPSNFA(rec(r), t);
//         case \multi-iteration(r): {
//             rnfa = rec(r);
//             rdfa = removeUnreachable(relabelSetPSNFA(convertPSNFAtoDFA(rnfa, {})));
//             n = iterationPSNFA(rdfa);
//         }
//         case meta(r, cacheMeta(nfa, _)): return nfa;
//         case meta(r, v): return rec(r);
//         default: throw "Unsupported regex: <regex>";
//     }

//     return shouldSimplify ? simplify(n) : n;
// }

// NFA[State] simplify(NFA[State] n) {
//     PSNFAComplement = getPSNFAComplementRetriever(tagsUniverse(n));
//     n2 = minimize(n, PSNFADisjoint, PSNFAComplement);
//     return mapStates(n2, State(set[set[State]] state){
//         return stateSet({stateSet(s) | s <- state});
//     });
// }

@doc {
    Converts the given regex to a NFA with an equivalent language

    Assumes the regex to be reduced
}
NFA[State] regexToPSNFA(Regex regex) 
    = regexToPSNFA(regex, true);
NFA[State] regexToPSNFA(Regex regex, bool shouldSimplify) {
    NFA[State] rec(Regex r) = regexToPSNFA(r, shouldSimplify);

    NFA[State] n;
    switch(regex) {
        case never(): n = neverPSNFA();
        case Regex::empty(): n = emptyPSNFA();
        case always(): n = alwaysPSNFA();
        case character(cc): n = charPSNFA(cc);
        case lookahead(r, la): n = lookaheadPSNFA(rec(r), rec(la));
        case lookbehind(r, lb): n = lookbehindPSNFA(rec(r), rec(lb));
        case \negative-lookahead(r, la): n = negativeLookaheadPSNFA(rec(r), rec(la));
        case \negative-lookbehind(r, lb): n = negativeLookbehindPSNFA(rec(r), rec(lb));
        case concatenation(h, t): n = concatPSNFA(rec(h), rec(t));
        case alternation(r1, r2): n = unionPSNFA(rec(r1), rec(r2));
        case subtract(r, s): n = strongSubtractPSNFA(rec(r), rec(s));
        case mark(t, r): return tagsPSNFA(rec(r), t);
        case \multi-iteration(r): {
            rnfa = rec(r);
            rdfa = removeUnreachable(relabelSetPSNFA(convertPSNFAtoDFA(rnfa, {})));
            n = iterationPSNFA(rdfa);
        }
        case meta(r, cacheMeta(nfa, _)): return nfa;
        case meta(r, v): return rec(r);
        default: throw "Unsupported regex: <regex>";
    }

    if(!shouldSimplify) return n;

    simplified = simplify(n);
    return simplified;
}

NFA[State] simplify(NFA[State] n) {
    return minimizeUnique(n);
}