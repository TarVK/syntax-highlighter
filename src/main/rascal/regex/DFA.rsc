module regex::DFA

import Set;
import List;

import regex::util::GetDisjointCharClasses;
import regex::NFA;

@doc {
    Converts a NFA to an equivalent NFA that satisfies all DFA restrictions (no epsilon transitions, and complete)
}
NFA[set[&T]] convertNFAtoDFA(NFA[&T] nfa) {
    initial = expandEpsilon(nfa, {nfa.initial});
    rel[set[&T], TransSymbol, set[&T]] transitions = {};
    set[set[&T]] found = {initial};

    set[set[&T]] queue = {initial};
    void init(set[&T] to) {
        if (!(to in found)) {
            found += {to};
            queue += {to};
        }
    }

    while(size(queue)>0) {
        <stateSet, queue> = takeOneFrom(queue);        
        bool hasRest = false;

        // Analyze extra symbols
        set[TransSymbol] otherSymbols = { sym 
            | state <- stateSet, <sym, _> <- nfa.transitions[state] 
            && !(character(_) := sym) && !(epsilon() := sym)};
        for(sym <- otherSymbols) {
            if(rest() == sym) hasRest = true;
            set[&T] toSet = expandEpsilon(nfa, 
                    {to | state <- stateSet, to <- nfa.transitions[state][sym]});
            init(toSet);
            transitions += <stateSet, sym, toSet>;
        }

        // Analyze main characters
        disjointCharClasses = getDisjointCharClasses(
            { charClass | state <- stateSet, <character(charClass), _> <- nfa.transitions[state]});
        for(ccr(charClass, ccMembers) <- disjointCharClasses) {
            set[&T] toSet = expandEpsilon(nfa, 
                {to | state <- stateSet, <character(cc), to> <- nfa.transitions[state] 
                    && cc in ccMembers});
            init(toSet);
            transitions += <stateSet, character(charClass), toSet>;
        }

        // Add rest if not present
        if(!hasRest){
            set[&T] toSet = {};
            transitions += <stateSet, rest(), toSet>;
        }
    }

    accepting = {stateSet | stateSet <- found && size(stateSet & nfa.accepting)>0};

    return <initial, transitions, accepting>;
}

set[TransSymbol] defaultComplement(set[TransSymbol] _) = {};