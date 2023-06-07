module regex::NFASimplification

import Set;
import regex::NFA;
import IO;



@doc {
    Removes duplicate states, ensuring the input and output NFAs are language-equivalent
}
NFA[set[&T]] removeDuplicates(NFA[&T] nfa) {
    rel[set[&K], TransSymbol, set[&K]] mapTransitions(rel[&K, TransSymbol, &K] transitions, set[set[&K]] classes) {
        stateMap = (s: g | g <- classes, s <- g);
        return {<stateMap[from], on, stateMap[to]> | <from, on, to> <- transitions};
    }

    states = nfa.transitions<0> + nfa.transitions<2> + {nfa.initial};    
    set[set[&T]] bisimilarClasses = partition(nfa.transitions, 
        {states - {nfa.initial} - nfa.accepting, {nfa.initial}, nfa.accepting});

    // Reverse edges, and perform another partition pass
    revTrans = mapTransitions(nfa.transitions<2, 1, 0>, bisimilarClasses);
    initialBisimilarClass = getOneFrom({g | g <- bisimilarClasses, nfa.initial in g});
    acceptingBisimilarClasses = {g | g <- bisimilarClasses, size(g & nfa.accepting)>0};
    set[set[set[&T]]] revBisimilarClasses = partition(revTrans, 
        {bisimilarClasses - {initialBisimilarClass} - acceptingBisimilarClasses, {initialBisimilarClass}, acceptingBisimilarClasses});
    classes = {{*r | r <- c} | c <- revBisimilarClasses};
    

    initial = getOneFrom({g | g <- classes, nfa.initial in g});
    transitions = mapTransitions(nfa.transitions, classes);
    accepting = {g | g <- classes, any(s <- g, s in nfa.accepting)};
    return <initial, transitions, accepting>;
}

set[set[&T]] partition(rel[&T, TransSymbol, &T] transitions, set[set[&T]] initPartition) {
    tuple[set[&T], set[&T]] split(set[set[&T]] classes, TransSymbol on, set[&T] group) {
        set[&T] includes = {};
        set[&T] excludes = {};

        bool hasTrans(&T from, set[&T] to) = size(transitions[from][on] & to)>0;

        first = getOneFrom(group);
        firstHas = (g: hasTrans(first, g) | g <- classes);

        for(state <- group) {
            shouldIncude = all(g <- classes, hasTrans(state, g) == firstHas[g]);
            if (shouldIncude) includes += state;
            else              excludes += state;
        }

        return <includes, excludes>;
    }

    set[set[&T]] classes = initPartition;
    stable = false;
    while(!stable) {
        stable = true;
        for(g <- classes, on <- transitions[g]<0>) {
            <includes, excludes> = split(classes, on, g);
            if (size(includes) > 0 && size(excludes) > 0) {
                classes -= {g};
                classes += {includes, excludes};
                stable = false;
                break;
            }
        }
    }

    return classes;
}

@doc {
    Relabels all states of the given NFA to a numeric one
}
NFA[int] relabel(NFA[&T] nfa) {
    states = nfa.transitions<0> + nfa.transitions<2>;

    maxID = 0;
    map[&T, int] stateMapping = ();
    for(state <- states) {
        stateMapping[state] = maxID;
        maxID += 1;
    }

    return <
        stateMapping[nfa.initial],
        {<stateMapping[from], sym, stateMapping[to]> | <from, sym, to> <- nfa.transitions},
        {stateMapping[state] | state <- nfa.accepting}
    >;
}

@doc {
    Removes all epsilon transitions
}
NFA[set[&T]] removeEpsilon(NFA[&T] nfa) {
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

        for(state <- stateSet, <sym, to> <- nfa.transitions[state]) {
            if(sym == epsilon()) continue;

            toSet = expandEpsilon(nfa, {to});
            init(toSet);
            transitions += <stateSet, sym, toSet>;
        }
    }

    accepting = {stateSet | stateSet <- found && size(stateSet & nfa.accepting)>0};

    return <initial, transitions, accepting>;
}