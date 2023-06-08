module regex::PSNFACombinators

import ParseTree;
import String;
import Set;
import IO;

import regex::util::GetCombinations;
import regex::util::GetDisjointCharClasses;
import regex::NFA;
import regex::NFASimplification;
import regex::PSNFA;

data State = simple(str name)
           | stateLabel(str name, State state)
           | statePair(State a, State b)
           | stateSet(set[State] states);

TransSymbol anyChar = character([range(1,0x10FFFF)]);

@doc {
    A PSNFA with a completely empty language
}
NFA[State] neverPSNFA() = <simple("never"), {}, {}>;

@doc {
    A PSNFA matching the language consisting of the empty string with any prefix and suffix
}
NFA[State] emptyPSNFA() = <
    simple("empty-prefix"), 
    {
        <simple("empty-prefix"), anyChar, simple("empty-prefix")>,
        <simple("empty-prefix"), matchStart(), simple("empty-main")>,
        <simple("empty-main"), matchEnd(), simple("empty-suffix")>,
        <simple("empty-suffix"), anyChar, simple("empty-suffix")>
    },
    {simple("empty-suffix")}
>;


@doc {
    A PSNFA matching the language consisting of the all strings with any prefix and suffix
}
NFA[State] alwaysPSNFA() = <
    simple("always-prefix"), 
    {
        <simple("always-prefix"), anyChar, simple("always-prefix")>,
        <simple("always-prefix"), matchStart(), simple("always-main")>,
        <simple("always-main"), matchEnd(), simple("always-suffix")>,
        <simple("always-main"), anyChar, simple("always-main")>,
        <simple("always-suffix"), anyChar, simple("always-suffix")>
    },
    {simple("always-suffix")}
>;

@doc {
    Constructs a PSNFA matching the language consisting of the string consisting of 1 character (in the specified class) with any prefix and suffix
}
NFA[State] charPSNFA(str char) = charPSNFA([range(charAt(char, 0), charAt(char, 0))]);
NFA[State] charPSNFA(CharClass char) = <
    simple("char-prefix"), 
    {
        <simple("char-prefix"), anyChar, simple("char-prefix")>,
        <simple("char-prefix"), matchStart(), simple("char-main0")>,
        <simple("char-main0"), character(char), simple("char-main1")>,
        <simple("char-main1"), matchEnd(), simple("char-suffix")>,
        <simple("char-suffix"), anyChar, simple("char-suffix")>
    },
    {simple("char-suffix")}
>;

@doc {
    Constructs a PSNFA matching the union of the languages described by PSNFA n1 and PSNFA n2
}
// NFA[State] unionPSNFA(NFA[State] n1, NFA[State] n2) = <
//     simple("union-init"), 
//     {
//         <simple("union-init"), epsilon(), stateLabel("union-1", n1.initial)>,
//         <simple("union-init"), epsilon(), stateLabel("union-2", n2.initial)>
//     } + {
//         <stateLabel("union-1", from), on, stateLabel("union-1", to)> | <from, on, to> <- n1.transitions
//     } + {
//         <stateLabel("union-2", from), on, stateLabel("union-2", to)> | <from, on, to> <- n2.transitions
//     },
//     {stateLabel("union-1", state) | state <- n1.accepting} + {stateLabel("union-2", state) | state <- n2.accepting}
// >;
NFA[State] unionPSNFA(NFA[State] n1, NFA[State] n2) = <
    simple("union-init"), 
    {
        <simple("union-init"), epsilon(), stateLabel("union-1", n1.initial)>,
        <simple("union-init"), epsilon(), stateLabel("union-2", n2.initial)>
    } + {
        <stateLabel("union-1", from), on, stateLabel("union-1", to)> | <from, on, to> <- n1.transitions
    } + {
        <stateLabel("union-2", from), on, stateLabel("union-2", to)> | <from, on, to> <- n2.transitions
    } + {
        <stateLabel("union-1", state), epsilon(), simple("union-final")> | state <- n1.accepting
    } + {
        <stateLabel("union-2", state), epsilon(), simple("union-final")> | state <- n2.accepting
    },
    {simple("union-final")}
>;

@doc {
    Constructs a PSNFA matching any word of the head PSNFA being followed by a word of the tail PSNFA, such that the prefixes and suffixes don't interfere
}
NFA[State] concatPSNFA(NFA[State] head, NFA[State] tail) {
    rel[TransSymbol, State] combine(
        State h, 
        State t, 
        rel[TransSymbol, State] hTrans, 
        rel[TransSymbol, State] tTrans
    ) = {<epsilon(), statePair(hNew, t)> | <epsilon(), hNew> <- hTrans}
        + {<epsilon(), statePair(h, tNew)> | <epsilon(), tNew> <- tTrans}
        + {<character(charClass), statePair(hNew, tNew)> 
            | <character(hCharClass), hNew> <- hTrans, <character(tCharClass), tNew> <- tTrans,
            charClass := fIntersection(hCharClass, tCharClass) && size(charClass)>0}
        + {<matchStart(), statePair(hNew, t)> | <matchStart(), hNew> <- hTrans}
        + {<epsilon(), statePair(hNew, tNew)> 
            | <matchEnd(), hNew> <- hTrans, <matchStart(), tNew> <- tTrans}
        + {<matchEnd(), statePair(h, tNew)> | <matchEnd(), tNew> <- tTrans};

    return productPSNFA(head, tail, combine);
}

@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's followed by a word in the lookahead PSNFA
}
NFA[State] lookaheadPSNFA(NFA[State] n, NFA[State] lookahead) {
    rel[TransSymbol, State] combine(
        State s, 
        State la, 
        rel[TransSymbol, State] sTrans, 
        rel[TransSymbol, State] laTrans
    ) = {<epsilon(), statePair(sNew, la)> | <epsilon(), sNew> <- sTrans}
        + {<epsilon(), statePair(s, laNew)> | <epsilon(), laNew> <- laTrans}
        + {<character(charClass), statePair(sNew, laNew)> 
            | <character(sCharClass), sNew> <- sTrans, <character(laCharClass), laNew> <- laTrans,
            charClass := fIntersection(sCharClass, laCharClass) && size(charClass)>0}
        + {<matchStart(), statePair(sNew, la)> | <matchStart(), sNew> <- sTrans}
        + {<matchEnd(), statePair(sNew, laNew)> 
            | <matchEnd(), sNew> <- sTrans, <matchStart(), laNew> <- laTrans}
        + {<epsilon(), statePair(s, laNew)> | <matchEnd(), laNew> <- laTrans};

    return productPSNFA(n, lookahead, combine);
}


@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's preceeded by a word in the lookbehind PSNFA
}
NFA[State] lookbehindPSNFA(NFA[State] n, NFA[State] lookbehind) {
    rel[TransSymbol, State] combine(
        State s, 
        State lb, 
        rel[TransSymbol, State] sTrans, 
        rel[TransSymbol, State] lbTrans
    ) = {<epsilon(), statePair(sNew, lb)> | <epsilon(), sNew> <- sTrans}
        + {<epsilon(), statePair(s, lbNew)> | <epsilon(), lbNew> <- lbTrans}
        + {<character(charClass), statePair(sNew, lbNew)> 
            | <character(sCharClass), sNew> <- sTrans, <character(lbCharClass), lbNew> <- lbTrans,
            charClass := fIntersection(sCharClass, lbCharClass) && size(charClass)>0}
        + {<epsilon(), statePair(s, lbNew)> | <matchStart(), lbNew> <- lbTrans}
        + {<matchStart(), statePair(sNew, lbNew)> 
            | <matchStart(), sNew> <- sTrans, <matchEnd(), lbNew> <- lbTrans}
        + {<matchEnd(), statePair(sNew, lb)> | <matchEnd(), sNew> <- sTrans};

    return productPSNFA(n, lookbehind, combine);
}


@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's not followed by a word in the lookahead PSNFA
}
NFA[State] negativeLookaheadPSNFA(NFA[State] n, NFA[State] lookahead) {
    rel[TransSymbol, State] combine(
        State s, 
        State la, 
        rel[TransSymbol, State] sTrans, 
        rel[TransSymbol, State] laTrans
    ) = {<epsilon(), statePair(sNew, la)> | <epsilon(), sNew> <- sTrans}
        + {<epsilon(), statePair(s, laNew)> | <epsilon(), laNew> <- laTrans}
        + {<character(charClass), statePair(sNew, laNew)> 
            | <character(sCharClass), sNew> <- sTrans, <character(laCharClass), laNew> <- laTrans,
            charClass := fIntersection(sCharClass, laCharClass) && size(charClass)>0}
        + {<matchStart(), statePair(sNew, la)> | <matchStart(), sNew> <- sTrans}
        + {<matchEnd(), statePair(sNew, laNew)> 
            | <matchEnd(), sNew> <- sTrans, <matchStart(), laNew> <- laTrans};

    if(<laInitial, laTransitions, laAccepting> := lookahead) {
        laNoEndTransitions = {<from, on == matchEnd() ? epsilon() : on, to> | <from, on, to> <- laTransitions};
        invertedLookahead = invertPSNFA(<laInitial, laNoEndTransitions, laAccepting>);
        return productPSNFA(n, invertedLookahead, combine);
    }

    // Shouldn't be reachable
    return n;
}


@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's not preceeded by a word in the lookbehind PSNFA
}
NFA[State] negativeLookbehindPSNFA(NFA[State] n, NFA[State] lookbehind) {
    rel[TransSymbol, State] combine(
        State s, 
        State lb, 
        rel[TransSymbol, State] sTrans, 
        rel[TransSymbol, State] lbTrans
    ) = {<epsilon(), statePair(sNew, lb)> | <epsilon(), sNew> <- sTrans}
        + {<epsilon(), statePair(s, lbNew)> | <epsilon(), lbNew> <- lbTrans}
        + {<character(charClass), statePair(sNew, lbNew)> 
            | <character(sCharClass), sNew> <- sTrans, <character(lbCharClass), lbNew> <- lbTrans,
            charClass := fIntersection(sCharClass, lbCharClass) && size(charClass)>0}
        + {<matchStart(), statePair(sNew, lbNew)> 
            | <matchStart(), sNew> <- sTrans, <matchEnd(), lbNew> <- lbTrans}
        + {<matchEnd(), statePair(sNew, lb)> | <matchEnd(), sNew> <- sTrans};

    
    if(<lbInitial, lbTransitions, lbAccepting> := lookbehind) {
        lbNoStartTransitions = {<from, on == matchStart() ? epsilon() : on, to> | <from, on, to> <- lbTransitions};
        invertedLookbehind = invertPSNFA(<lbInitial, lbNoStartTransitions, lbAccepting>);
        return productPSNFA(n, invertedLookbehind, combine);
    }

    // Shouldn't be reachable
    return n;
}

@doc {
    Constructs a PSNFA matching all words that were not part of the language of PSNFA n
}
NFA[State] invertPSNFA(NFA[State] n) {
    NFA[State] dfa = relabelSetPSNFA(convertPSNFAtoDFA(n));
    NFA[State] dfaInverted = <dfa.initial, dfa.transitions, getStates(dfa) - dfa.accepting>;
    return removeUnreachable(dfaInverted);
}

@doc {
    Constructs a PSNFA matching all words that are matched by n1 and n2
}
NFA[State] productPSNFA(NFA[State] n1, NFA[State] n2) {
    rel[TransSymbol, State] combine(
        State s1, 
        State s2, 
        rel[TransSymbol, State] trans1, 
        rel[TransSymbol, State] trans2
    ) = {<epsilon(), statePair(s1New, s2)> | <epsilon(), s1New> <- trans1}
        + {<epsilon(), statePair(s1, s2New)> | <epsilon(), s2New> <- trans2}
        + {<character(charClass), statePair(s1New, s2New)> 
            | <character(s1CharClass), s1New> <- trans1, <character(s2CharClass), s2New> <- trans2,
            charClass := fIntersection(s1CharClass, s2CharClass) && size(charClass)>0}
        + {<matchStart(), statePair(s1New, s2New)> | <matchStart(), s1New> <- trans1, <matchStart(), s2New> <- trans2}
        + {<matchEnd(), statePair(s1New, s2New)> | <matchEnd(), s1New> <- trans1, <matchEnd(), s2New> <- trans2};

    return productPSNFA(n1, n2, combine);
}

@doc {
    Constructs a PSNFA matching all words in n, that are not in subt
}
NFA[State] subtractPSNFA(NFA[State] n, NFA[State] subt) = productPSNFA(n, invertPSNFA(subt));

@doc {
    Constructs a PSNFA matching one or more repititions of the n PSNFA, considering only valid overlap of prefix and suffix

    Use a simplified DFA as input (without dead-end states) to prevent unnecessary expnential blow up
}
NFA[State] iterationPSNFA(NFA[State] n) {
    State initial = stateSet({n.initial});
    rel[State, TransSymbol, State] transitions = {};
    set[State] found = {};

    <prefixStates, _, _> = getPSNFApartition(n);

    set[State] queue = {initial};
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);

        if(stateSet(states) := state) {
            trans = {<from, on, to> | <from, on, to> <- n.transitions, from in states};

            // Get all standard epsilon transitions
            rel[TransSymbol, State] newTransitions = 
                {<epsilon(), stateSet(newStates)> | <_, epsilon(), to> <- trans, newStates := states + {to}, newStates != states}
                + {<epsilon(), stateSet(newStates)> | <from, epsilon(), to> <- trans, newStates := states - {from} + {to}, newStates != states};

            // Get all possible synchronized character transitions
            outChars = {cc | character(cc) <- trans<1>};
            disjointOutChars = getDisjointCharClasses(outChars);
            for(ccr(cc, includes) <- disjointOutChars) {
                stateCharTransitions = {<from, toOptions> | from <- states, 
                    toOptions := {to | <character(on), to> <- n.transitions[from], on in includes}, 
                    size(toOptions)>0};

                allStatesTransition = size(states - stateCharTransitions<0>)==0;
                if(!allStatesTransition) continue;

                newTransitions += {<character(cc), stateSet(to)> | to <- getCombinations(stateCharTransitions<1>)};
            }

            // Match start/stop transitions
            curPrefixStates = states & prefixStates;
            allPrefix = size(curPrefixStates) == size(states);
            if(allPrefix)
                newTransitions += {<matchStart(), stateSet(states + {to})>, <matchStart(), stateSet(states - {from} + {to})> | <from, matchStart(), to> <- trans};
            noPrefix = size(curPrefixStates) == 0;
            if(noPrefix)
                newTransitions += {<matchEnd(), stateSet(states - {from} + {to})> | <from, matchEnd(), to> <- trans};

            // Match loop transitions
            newTransitions += {<epsilon(), stateSet(states - {fromPrefix, fromMain} + {toMain, toSuffix})>, <epsilon(), stateSet(states - {fromMain} + {toMain, toSuffix})> | <fromPrefix, matchStart(), toMain> <- trans, <fromMain, matchEnd(), toSuffix> <- trans};

            // println(<states, newTransitions>);
            for(<sym, to> <- newTransitions) {
                transitions += <state, sym, to>;
                if(to in found) continue;
                found += to;
                queue += to;
            }
        }
    }

    accepting = {state | state:stateSet(states) <- found, all(s <- states, s in n.accepting)};

    return <initial, transitions, accepting>;   
}

//         Helpers
// ------------------------
@doc {
    Turns the PSNFA containing sets of states into a PSNFA with State instances, to be reusable in other PSNFA combinators
}
NFA[State] relabelSetPSNFA(NFA[set[State]] nfa) = mapStates(nfa, State (set[State] states) { return stateSet(states); });

@doc {
    Turns the PSNFA containing int states into a PSNFA with State instances, to be reusable in other PSNFA combinators
}
NFA[State] relabelIntPSNFA(NFA[int] nfa) = mapStates(nfa, State (int state) { return simple("<state>"); });


@doc {
    A reusable function that can be used for arbitrary product automata
}
NFA[State] productPSNFA(
    NFA[State] n1, 
    NFA[State] n2, 
    rel[TransSymbol, State](
        State s1, 
        State s2, 
        rel[TransSymbol, State] s1Trans, 
        rel[TransSymbol, State] s2Trans
    ) combine
) {
    State initial = statePair(n1.initial, n2.initial);
    rel[State, TransSymbol, State] transitions = {};
    set[State] found = {};

    set[State] queue = {initial};
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);

        if(statePair(s1, s2) := state) {
            rel[TransSymbol, State] newTransitions = combine(s1, s2, n1.transitions[s1], n2.transitions[s2]);

            for(<sym, to> <- newTransitions) {
                transitions += <state, sym, to>;
                if(to in found) continue;
                found += to;
                queue += to;
            }
        }
    }

    accepting = {state | state:statePair(s1, s2) <- found, s1 in n1.accepting, s2 in n2.accepting};

    return <initial, transitions, accepting>;   
}