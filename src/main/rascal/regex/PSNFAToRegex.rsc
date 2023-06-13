module regex::PSNFAToRegex

import IO;
import Set;

import regex::Regex;
import regex::NFA;

data TransSymbol = regexp(Regex r);

// -------------------------------------
// This file is incomplete, 
// and no function exists for fully 
// converting a given PSNFA to regex yet
// -------------------------------------

@doc {
    Converts all possible transitions from single character transitions to regular expression transitions, reducing the states
}
NFA[&T] transitionsToRegex(NFA[&T] n) {
    internalStates = getStates(n) - {n.initial} - n.accepting;

    n = replaceSelfLoopsByRegex(n, n.initial, false, true);
    for(state <- n.accepting) {
        n = replaceSelfLoopsByRegex(n, state, true, false);
    }
    for(state <- internalStates) {
        n = replaceSelfLoopsByRegex(n, state);
    }

    for(state <- internalStates) {
        n = replaceStateByRegex(n, state);
    }

    return n;
}

@doc {
    Removes the self loops from the given state by replacing it by a regular expression, if possible
}
NFA[&T] replaceSelfLoopsByRegex(NFA[&T] n, &T state) = replaceSelfLoopsByRegex(n, state, true, true);
NFA[&T] replaceSelfLoopsByRegex(NFA[&T] n, &T state, bool allowIn, bool allowOut) {
    transitions = n.transitions;
    outTrans = n.transitions[state];
    canAugmentOut = allowOut && all(<on, _> <- outTrans, augmentable(on)); // Includes self loops

    rel[TransSymbol, &T] inTrans = {};
    canAugmentIn = false;
    if(!canAugmentOut && allowIn) {
        inTrans = (transitions<2, 1, 0>)[state];
        canAugmentIn = all(<on, _> <- inTrans, augmentable(on)); // Includes self loops
    }

    if(!canAugmentIn && !canAugmentOut) return n;

    selfTrans = (outTrans<1, 0>)[state];
    if(size(selfTrans)==0) return n;
    for(on <- selfTrans)
        transitions -= <state, on, state>;

    selfRegexes = {Regex::character(cc) | TransSymbol::character(cc) <- selfTrans} 
                + {r | regexp(r) <- selfTrans};
    selfRegex = Regex::concatenation([r | r <- selfRegexes]);

    if(canAugmentOut) {
        for(<on, to> <- outTrans) {
            if(to == state) continue;
            r = getRegex(on);
            newOn = regexp(Regex::concatenation(Regex::iteration(selfRegex), r));
            transitions = transitions - {<state, on, to>} + {<state, newOn, to>};
        }
    } else {
        for(<on, from> <- inTrans) {
            if(from == state) continue;
            r = getRegex(on);
            newOn = regexp(Regex::concatenation(r, Regex::iteration(selfRegex)));
            transitions = transitions - {<from, on, state>} + {<from, newOn, state>};
        }
    }

    return <n.initial, transitions, n.accepting>;
}

@doc {
    Removes the the given state by replacing it by a regular expression, if possible

    Assumes self-loops to have been replaced beforehand
}
NFA[&T] replaceStateByRegex(NFA[&T] n, &T state) {
    transitions = n.transitions;
    outTrans = n.transitions[state];
    inTrans = (transitions<2, 1, 0>)[state];

    hasSelf = state in outTrans<1>;
    if(hasSelf) return n;

    needsOut = any(s <- inTrans<0>, !augmentable(s)); // We need the out transitions to be kept, if any in transition needs to be kept
    needsIn = any(s <- outTrans<0>, !augmentable(s));
    if(needsOut && needsIn) return n;

    if(!needsOut) for(<on, to> <- outTrans, augmentable(on))
        transitions -= <state, on, to>;
    if(!needsIn) for(<on, from> <- inTrans, augmentable(on))
        transitions -= <from, on, state>;

    set[&T] changedFrom = {};
    for(<onFrom, from> <- inTrans) {
        if(!augmentable(onFrom)) continue;
        for(<onTo, to> <- outTrans) {
            if(!augmentable(onTo)) continue;
            newOn = regexp(Regex::concatenation(getRegex(onFrom), getRegex(onTo)));
            transitions += <from, newOn, to>;
            changedFrom += {from};
        }
    }

    out = <n.initial, transitions, n.accepting>;
    for(from <- changedFrom)
        out = combineOutTransitions(out, from);
    return out;
}

@doc {
    Checks whether the given state has multiple transitions to the same state, and if soe combines them to a single transition
}
NFA[&T] combineOutTransitions(NFA[&T] n, &T state) {
    transitions = n.transitions;
    outTrans = n.transitions[state];

    toIndexed = outTrans<1,0>;
    for(to <- toIndexed<0>) {
        allOn = {on | on <- toIndexed[to], augmentable(on)};
        if(size(allOn)<2) continue;

        for(on <- allOn)
            transitions -= <state, on, to>;

        regexes = [getRegex(on) | on <- allOn];
        newRegex = Regex::alternation(regexes);
        transitions += <state, regexp(newRegex), to>;
    }

    return <n.initial, transitions, n.accepting>;
}

bool augmentable(TransSymbol symb) = (regexp(_) := symb) || (TransSymbol::character(_) := symb);
Regex getRegex(regexp(r)) = r;
Regex getRegex(TransSymbol::character(cc)) = Regex::character(cc);