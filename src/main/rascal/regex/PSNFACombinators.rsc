module regex::PSNFACombinators

import ParseTree;
import String;
import Set;

import regex::util::GetDisjointCharClasses;
import regex::NFA;
import regex::PSNFA;

data State = simple(str name)
           | stateLabel(str name, State state)
           | statePair(State a, State b)
           | stateSet(set[State] states);

TransSymbol anyChar = character([range(1,0x10FFFF)]);

@doc {
    A PSNFA matching the language consisting of the empty string with any prefix and suffix
}
NFA[State] emptyPSNFA = <
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
            | <character(hCharClass), hNew> <- hTrans, <character(tCharClass), tNew> <- tTrans
            && charClass := fIntersection(hCharClass, tCharClass) && size(charClass)>0}
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
            | <character(sCharClass), sNew> <- sTrans, <character(laCharClass), laNew> <- laTrans
            && charClass := fIntersection(sCharClass, laCharClass) && size(charClass)>0}
        + {<matchStart(), statePair(sNew, la)> | <matchStart(), sNew> <- sTrans}
        + {<matchEnd(), statePair(sNew, laNew)> 
            | <matchEnd(), sNew> <- sTrans, <matchStart(), laNew> <- laTrans}
        + {<epsilon(), statePair(s, laNew)> | <matchEnd(), laNew> <- laTrans};

    return productPSNFA(n, lookahead, combine);
}


@doc {
    Constructs a PSNFA matching any word of the nfa PSNFA, if it's preceeded by a word in the lookbehind PSNFA
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
            | <character(sCharClass), sNew> <- sTrans, <character(lbCharClass), lbNew> <- lbTrans
            && charClass := fIntersection(sCharClass, lbCharClass) && size(charClass)>0}
        + {<epsilon(), statePair(s, lbNew)> | <matchStart(), lbNew> <- lbTrans}
        + {<matchStart(), statePair(sNew, lbNew)> 
            | <matchStart(), sNew> <- sTrans, <matchEnd(), lbNew> <- lbTrans}
        + {<matchEnd(), statePair(sNew, lb)> | <matchEnd(), sNew> <- sTrans};

    return productPSNFA(n, lookbehind, combine);
}

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
        // queue -= stateSet;

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

    accepting = {state | state:statePair(s1, s2) <- found && s1 in n1.accepting && s2 in n2.accepting};

    return <initial, transitions, accepting>;   
}