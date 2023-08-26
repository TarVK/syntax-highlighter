module regex::NFACombinators

import util::Maybe;
import List;
import Set;

import regex::NFA;
import regex::NFATypes;
import regex::util::GetDisjointCharClasses;

@doc {
    A function to create NFA product automata
}
NFA[tuple[&T, &T]] productNFA(NFA[&T] n1, NFA[&T] n2) 
    = productNFA(n1, n2, standardNFATransMatcher);
NFA[tuple[&T, &T]] productNFA(
    NFA[&T] n1, 
    NFA[&T] n2, 
    Maybe[TransSymbol] (TransSymbol on1, TransSymbol on2) match
) {
    tuple[&T, &T] initial = <n1.initial, n2.initial>;
    rel[tuple[&T, &T], TransSymbol, tuple[&T, &T]] transitions = {};
    set[tuple[&T, &T]] found = {};

    set[tuple[&T, &T]] queue = {initial};
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);
        <s1, s2> = state;
        set[tuple[TransSymbol, tuple[&T, &T]]] newTransitions = {};

        n1Trans = n1.transitions[s1];
        n2Trans = n2.transitions[s2];

        nonEpsilon1 = {<on, to> | <on, to> <- n1Trans, on != epsilon()};
        nonEpsilon2 = {<on, to> | <on, to> <- n2Trans, on != epsilon()};

        for(<epsilon(), to> <- n1Trans)
            newTransitions += <epsilon(), <to, s2>>;
        for(<epsilon(), to> <- n2Trans)
            newTransitions += <epsilon(), <s1, to>>;

        for(<on1, to1> <- nonEpsilon1, <on2, to2> <- nonEpsilon2)
            if(just(on) := match(on1, on2)) 
                newTransitions += <on, <to1, to2>>;

        for(<sym, to> <- newTransitions) {
            transitions += <state, sym, to>;
            if(to in found) continue;
            found += to;
            queue += to;
        }
    }

    accepting = {state | state:<s1, s2> <- found, s1 in n1.accepting, s2 in n2.accepting};

    return <initial, transitions, accepting, ()>;
}

Maybe[TransSymbol] standardNFATransMatcher(TransSymbol on1, TransSymbol, on2) {
    if(character(cc1) := on1 && character(cc2) := on2) {
        cc = fIntersection(cc1, cc2);
        if(size(cc)<=0) return nothing();
        return character(cc);
    }
    return nothing();
}