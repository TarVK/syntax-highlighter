module regex::PSNFACombinators

import ParseTree;
import String;
import Set;
import IO;

import regex::util::GetCombinations;
import regex::util::GetDisjointCharClasses;
import regex::util::AnyCharClass;
import regex::NFA;
import regex::NFASimplification;
import regex::PSNFA;

// State labels that can be used to ensure unique states
data State = simple(str name)
           | stateLabel(str name, State state)
           | statePair(State a, State b)
           | stateSet(set[State] states);

TransSymbol anyChar = character(anyCharClass());

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
    Constructs a PSNFA matching any word of the head PSNFA being followed by a word of the tail PSNFA, such that the prefixes and suffixes don't interfere. Assumes capture groups in head and tail to contain unique tags.
}
NFA[State] concatPSNFA(NFA[State] head, NFA[State] tail) {
    rel[TransSymbol, State] combine(
        State h, 
        State t, 
        rel[TransSymbol, State] hTrans, 
        rel[TransSymbol, State] tTrans
    ) = getStandardTransitionSync(h, t, hTrans, tTrans)
        + {<border(borders), statePair(hNew, t)> 
            | <border(borders), hNew> <- hTrans,
              !any(<match(), end()> <- borders)}
        + {<mergeTrans(hRest, tRest), statePair(hNew, tNew)> 
            | <border({<match(), end()>, *hRest})> <- hTrans,
              <border({<match(), begin()>, *tRest})> <- tTrans}
        + {<border(borders), statePair(h, tNew)> 
            | <border(borders), tNew> <- tTrans,
              !any(<match(), begin()> <- borders)};

    return productPSNFA(head, tail, combine);
}


@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's followed by a word in the lookahead PSNFA
}
NFA[State] lookaheadPSNFA(NFA[State] n, NFA[State] lookahead) = productPSNFA(n, lookahead, combineLA);
rel[TransSymbol, State] combineLA(
        State s, 
        State la, 
        rel[TransSymbol, State] sTrans, 
        rel[TransSymbol, State] laTrans
    ) = getStandardTransitionSync(s, la, sTrans, laTrans)
        + {<border(borders), statePair(sNew, la)> 
            | <border(borders), sNew> <- sTrans,
              {<match(), end()>, *_} !:= borders}
        + {<mergeTrans(sBorders, removeMatch(laBorders)), statePair(sNew, laNew)> 
            | <border(sBorders:{<match(), end()>, *_}), sNew> <- sTrans,
              <border(laBorders:{<match(), begin()>, *_}), laNew> <- laTrans}
        + {<optBorder(removeMatch(borders)), statePair(s, laNew)> 
            | <border(borders), laNew> <- laTrans,
              {<match(), begin()>, *_} !:= borders};

set[Border] removeMatch(set[Border] borders) = {b <- borders, <match(), _> !:= b};

@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's preceeded by a word in the lookbehind PSNFA
}
NFA[State] lookbehindPSNFA(NFA[State] n, NFA[State] lookbehind) = productPSNFA(n, lookbehind, combineLB);
rel[TransSymbol, State] combineLB(
    State s, 
    State lb, 
    rel[TransSymbol, State] sTrans, 
    rel[TransSymbol, State] lbTrans
) = getStandardTransitionSync(s, lb, sTrans, lbTrans)
    + {<optBorder(removeMatch(borders)), statePair(s, lbNew)>
        | <border(borders), lbNew> <- lbTrans,
            {<match(), end()>, *_} !:= borders}
    + {<mergeTrans(removeMatch(lbBorders), sBorders), statePair(sNew, lbNew)>
        | <border(sBorders:{<match(), begin()>, *_}), sNew> <- sTrans,
            <border(lbBorders:{<match(), end()>, *_}), lbNew> <- lbTrans}
    + {<border(borders), statePair(sNew, lb)>
        | <border(borders), sNew> <- sTrans,
            {<match(), begin()>, *_} !:= borders};


@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's not followed by a word in the lookahead PSNFA
}
NFA[State] negativeLookaheadPSNFA(NFA[State] n, NFA[State] lookahead) {
    if(<laInitial, laTransitions, laAccepting> := lookahead) {
        laNoEndTransitions = {<from, newOn, to> | <from, on, to> <- laTransitions, 
            newOn := ((border({<match(), end()>, *rest}) := on) ? optBorder(rest) : on)};
        invertedLookahead = invertPSNFA(<laInitial, laNoEndTransitions, laAccepting>);
        return productPSNFA(n, invertedLookahead, combineLA);
    }

    // Shouldn't be reachable
    return n;
}


@doc {
    Constructs a PSNFA matching any word of the n PSNFA, if it's not preceeded by a word in the lookbehind PSNFA
}
NFA[State] negativeLookbehindPSNFA(NFA[State] n, NFA[State] lookbehind) {
    if(<lbInitial, lbTransitions, lbAccepting> := lookbehind) {
        lbNoStartTransitions = {<from, newOn, to> | <from, on, to> <- lbTransitions, 
            newOn := ((border({<match(), begin()>, *rest}) := on) ? optBorder(rest) : on)};
        invertedLookbehind = invertPSNFA(<lbInitial, lbNoStartTransitions, lbAccepting>, {n});
        return productPSNFA(n, invertedLookbehind, combineLB);
    }

    // Shouldn't be reachable
    return n;
}

@doc {
    Constructs a PSNFA matching all words that were not part of the language of PSNFA n
}
NFA[State] invertPSNFA(NFA[State] n) {
    NFA[State] dfa = convertNFAtoDFA(n);
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
    ) = getStandardTransitionSync(s1, s2, trans1, trans2)
        + {<border(borders), statePair(s1New, s2New)> | <border(borders), s1New> <- trans1, <border(borders), s2New> <- trans2};

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

            // TODO: look into possibility of mirroring greedy search behavior of only caring about the capture group of the last iteration
            // Could also support capture groups only in the capture of iterations, but not prefix/suffix. This should not be very complex as it can't introduce overlap
            if(any(captureStart(_) <- trans<1>))
                throw "Capture groups are not supported within iterations";

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
            newTransitions += {
                    <on, stateSet(states - {fromPrefix, fromMain} + {toMain, toSuffix})>, 
                    <on, stateSet(states - {fromMain} + {toMain, toSuffix})> 
                | <fromPrefix, border({<match(), begin()>, *prefixBorders}), toMain> <- trans, 
                  <fromMain, border({<match(), end()>, *mainBorders}), toSuffix> <- trans,
                  on := mergeTrans(prefixBorders, suffixBorders)};

            for(<sym, to> <- newTransitions) {
                transitions += <state, sym, to>;
                if(to in found) continue;
                found += to;
                queue += to;
            }
        }
    }

    accepting = {state | state:stateSet(states) <- found, all(s <- states, s in n.accepting)};

    return mergeBorders(<initial, transitions, accepting>);
}

@doc {
    Creates a PSNFA that tags the matched language (excluding prefix/suffix) with the given tags
}
NFA[State] capturePSNFA(NFA[State] n, set[value] tags) = mergeBorders(<
    n.initial, 
    { <from, matchStart(), stateLabel("captureStart", to)>, 
        <stateLabel("captureStart", to), captureStart(tags), to> 
        | <from, matchStart(), to> <- n.transitions }
    + { <from, captureEnd(tags), stateLabel("captureEnd", from)>, 
        <stateLabel("captureEnd", from), matchEnd(), to>
        | <from, matchEnd(), to> <- n.transitions }
    + { <from, on, to> | <from, on, to> <- n.transitions, !(matchStart() == on || matchEnd() == on)},
    n.accepting
>);

//         Helpers
// ------------------------
@doc {
    Retrieves the standard transitions that deal with character and epsilon transition synchronization
}
rel[TransSymbol, State] getStandardTransitionSync(  
    State s1, 
    State s2, 
    rel[TransSymbol, State] s1Trans, 
    rel[TransSymbol, State] s2Trans
) = {<epsilon(), statePair(s1New, s2)> | <epsilon(), s1New> <- s1Trans}
    + {<epsilon(), statePair(s1, s2New)> | <epsilon(), s2New> <- s2Trans}
    + {<character(charClass), statePair(s1New, s2New)> 
        | <character(s1CharClass), s1New> <- s1Trans, <character(s2CharClass), s2New> <- s2Trans,
        charClass := fIntersection(s1CharClass, s2CharClass) && size(charClass)>0}
    + {<character(charClass), statePair(s1New, s2New)>
        | <character(s1CharClass), s1New> <- s1Trans, <rest(), s2New> <- s2Trans,
        charClass := restChars(s1CharClass, s2Trans) && size(charClass)>0}
    + {<character(charClass), statePair(s1New, s2New)>
        | <rest(), s1New> <- s1Trans, <character(s2CharClass), s2New> <- s2Trans,
        charClass := restChars(s2CharClass, s1Trans) && size(charClass)>0};

CharClass restChars(CharClass cc, rel[TransSymbol, State] trans) =
    (cc | fDifference(cc, rem) | <character(rem), _> <- trans);

@doc {
    Retrieves the transitions that combine the capture group transitions of the two states
}
rel[TransSymbol, State] getCaptureTransitionCombination(
    State s1, 
    State s2, 
    rel[TransSymbol, State] s1Trans, 
    rel[TransSymbol, State] s2Trans
) = {<captureStart(tags), statePair(s1New, s2)> | <captureStart(tags), s1New> <- s1Trans}
    + {<captureEnd(tags), statePair(s1New, s2)> | <captureEnd(tags), s1New> <- s1Trans}
    + {<captureStart(tags), statePair(s1, s2New)> | <captureStart(tags), s2New> <- s2Trans}
    + {<captureEnd(tags), statePair(s1, s2New)> | <captureEnd(tags), s2New> <- s2Trans};

    
@doc {
    Merges border sets together to an appropriate transition (epsilon if no borders are present)
}
TransSymbol mergeTrans(set[Border] borders1, set[Border] borders2) = optBorder({*borders1, *borders2});

@doc {
    Retrieves a border transition if borders are provided, or an epsilon transition otherwise
}
TransSymbol optBorder(set[Border] borders) {
    if(size(borders)==0) return epsilon();
    return TransSymbol::border(borders);
}

@doc {
    Considers any matchStart, captureStart, matchEnd, and captureEnd transitions, and ensures that ending takes priority over starting, if starting can still be done from the next state. Without this, it would generate both orders (first start then end, and first end then start). 
}
rel[TransSymbol, State] orderStartAndEnd(rel[TransSymbol, State] transitions) {

}

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
    set[State] mergeBorderStates = {};

    set[State] queue = {initial};
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);

        if(statePair(s1, s2) := state) {
            rel[TransSymbol, State] newTransitions = combine(s1, s2, n1.transitions[s1], n2.transitions[s2]);

            for(<sym, to> <- newTransitions) {
                if(border(_) <- sym) mergeBorderStates += state;

                transitions += <state, sym, to>;
                if(to in found) continue;
                found += to;
                queue += to;
            }
        }
    }

    accepting = {state | state:statePair(s1, s2) <- found, s1 in n1.accepting, s2 in n2.accepting};

    return mergeBorders(<initial, transitions, accepting>, mergeBorderStates);  
}