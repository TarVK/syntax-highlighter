module regex::simplifyNFA

import Set;
import regex::NFA;
import IO;

@doc {
    Removes duplicate states, ensuring the input and output NFAs are bisimilar
}
NFA[set[&T]] removeDuplicates(NFA[&T] nfa) {
    set[set[&T]] classes = partition(nfa);    

    stateMap = (s: g | g <- classes, s <- g);
    initial = getOneFrom({g | g <- classes, nfa.initial in g});
    transitions = {<stateMap[from], on, stateMap[to]> | <from, on, to> <- nfa.transitions};
    accepting = {g | g <- classes, any(s <- g, s in nfa.accepting)};
    return <initial, transitions, accepting>;
}

set[set[&T]] partition(NFA[&T] nfa) {
    tuple[set[&T], set[&T]] split(set[set[&T]] classes, TransSymbol on, set[&T] group) {
        set[&T] includes = {};
        set[&T] excludes = {};

        bool hasTrans(&T from, set[&T] to) = size(nfa.transitions[from][on] & to)>0;

        first = getOneFrom(group);
        firstHas = (g: hasTrans(first, g) | g <- classes);

        for(state <- group) {
            shouldIncude = all(g <- classes, hasTrans(state, g) == firstHas[g]);
            if (shouldIncude) includes += state;
            else              excludes += state;
        }

        return <includes, excludes>;
    }

    states = nfa.transitions<0> + nfa.transitions<2> + {nfa.initial};
    set[set[&T]] classes = {states};
    stable = false;
    while(!stable) {
        stable = true;
        for(g <- classes, on <- nfa.transitions[g]<0>) {
            <includes, excludes> = split(classes, on, g);
            if (size(includes) > 0 && size(excludes) > 0) {
                classes -= {g};
                classes += {includes, excludes};
                stable = false;
                break;
            }
        }
    }

    println(states);
    println(classes);
    println(states == {*g | g <- classes});
    return classes;
}