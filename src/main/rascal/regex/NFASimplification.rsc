module regex::NFASimplification

import Set;
import IO;
import ParseTree;
import Relation;

import regex::DFA;
import regex::NFA;
import regex::PSNFA;
import regex::Tags;
import regex::util::expandEpsilon;
import regex::util::GetDisjointCharClasses;


@doc {
    Minimizes the given NFA using a DFA minimization algorithm, nad gets rid of unreachable/dead states.

    // TODO: in order to use the minimized DFA for equivalence checking, we have to normalize multiple transitions between the same states. Currently we can have both these transitions in the same DFA:
    ```
    A -![01]-> B
    A -[1]-> B
    ```
    This should be merged/normalized into:
    ```
    A -![0]-> B
    ```
    Without doing this, there is not a unique minized DFA representing the input NFA
}
NFA[set[set[&T]]] minimize(NFA[&T] nfa, ComputeDisjoint getDisjoint, ComputeRemainder getRemainder) {
    dfa = convertNFAtoDFA(removeUnreachable(nfa), getDisjoint, getRemainder);
    overlapLessDfa = removePartialEdgeOverlap(dfa, getDisjoint);
    minimizedDFA = minimizeDFA(overlapLessDfa);
    return removeUnreachable(minimizedDFA);
}

@doc {
    Minimizes the given DFA using a DFA minimization algorithm, but does not get rid of unreachable/dead states.
    Hence this requires the input to be a valid DFA!

    Assumes none of the transition symbols to partially overlap, if they do, the resulting dfa might not be minimal.
}
NFA[set[&T]] minimizeDFA(NFA[&T] dfa) {
    
    p = partition(dfa);
    stateMap = (state:states | states <- p, state <- states);

    initial = stateMap[dfa.initial];
    transitions = {<stateMap[from], on, stateMap[to]> | <from, on, to> <- dfa.transitions};
    accepting = {states | states <- p, any(state <- states, state in dfa.accepting)};

    return <initial, transitions, accepting, ()>;
}

set[set[&T]] partition(NFA[&T] n) {
    // Implementation of Hopcroft's algorithm: https://en.wikipedia.org/wiki/DFA_minimization#Hopcroft's_algorithm
    reverseEdges = n.transitions<2, 1, 0>;

    set[set[&T]] partition = {getStates(n) - n.accepting, n.accepting};
    set[set[&T]] queue = partition;

    while (size(queue) > 0) {
        <toStates, queue> = takeOneFrom(queue);

        inComing = reverseEdges[toStates];
        transSymbols = inComing<0>;
        for(transSymbol <- transSymbols) {
            fromStates = inComing[transSymbol];
            for(set[&T] eqClass <- partition) {
                includingTransition = (fromStates & eqClass);
                excludingTransition = eqClass - fromStates;
                // If some of the states in the equivalnce class have this transition, but not all, then they aren't behavioraly equivalent
                if(size(includingTransition)>0 && size(excludingTransition)>0) {
                    partition = (partition - {eqClass}) + {includingTransition} + {excludingTransition};
                    if (eqClass in queue)
                        queue = (queue - {eqClass}) + {includingTransition} + {excludingTransition};
                    else if (size(includingTransition) < size(excludingTransition))
                        queue += {includingTransition};
                    else
                        queue += {excludingTransition};
                }
            }
        }
    }

    return partition;
}

@doc {
    Transforms n into a new NFA m with an identical language, such that:
    - for every edge in m, two edges overlaping in character/set collection implies they are fully identical
}
NFA[&T] removePartialEdgeOverlap(NFA[&T] n, ComputeDisjoint getDisjoint) {
    transitionSymbols = n.transitions<1>;
    disjointTransitionSymbols = getDisjoint(transitionSymbols);

    orTransToDisjoint = Relation::index(disjointTransitionSymbols<1, 0>);
    rel[&T, TransSymbol, &T] transitions = {
        <from, on, to>
        | <from, onOr, to> <- n.transitions,
        on <- orTransToDisjoint[onOr]
    };

    return <n.initial, transitions, n.accepting, ()>;
}

@doc {
    Removes all epsilon transitions
}
NFA[set[&T]] removeEpsilon(NFA[&T] n) {
    set[&T] initial = expandEpsilon(n, {n.initial});
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
        <setOfStates, queue> = takeOneFrom(queue);

        for(state <- setOfStates, <sym, to> <- n.transitions[state]) {
            if(sym == epsilon()) continue;

            toStates = expandEpsilon(n, {to});
            init(toStates);
            transitions += <setOfStates, sym, toStates>;
        }
    }

    accepting = {setOfStates | setOfStates <- found && size(setOfStates & n.accepting)>0};

    return <initial, transitions, accepting, ()>;
}

@doc {
    Removes all states from the NFA that are not reachable from initial state to accepting state
}
NFA[&T] removeUnreachable(NFA[&T] n)
    = removeUnreachable(n, {n.initial}, n.accepting);
NFA[&T] removeUnreachable(NFA[&T] n, set[&T] initial, set[&T] accepting) {
    // Forward search
    set[&T] queue = initial;
    set[&T] reachableInitial = queue;
    while(size(queue)>0) {
        from = queue;
        toStates = n.transitions[from]<1>;
        newToStates = toStates - reachableInitial;
        reachableInitial += newToStates;
        queue = newToStates;
    }

    // Backward search
    revTransitions = n.transitions<2, 1, 0>;
    queue = accepting;
    set[&T] reachableAccepting = queue;
    while(size(queue)>0) {
        to = queue;
        fromStates = revTransitions[to]<1>;
        newFromStates = fromStates - reachableAccepting;
        reachableAccepting += newFromStates;
        queue = newFromStates;
    }

    return filterStates(n, reachableInitial & reachableAccepting);
}
NFA[&T] filterStates(NFA[&T] n, set[&T] states) {
    return <
        n.initial,
        {<from, on, to> | <from, on, to> <- n.transitions, from in states, to in states},
        {s | s <- n.accepting, s in states},
        ()
    >;
}

@doc {
    Merges edges in the given automaton
}
NFA[&T] mergeEdges(NFA[&T] n, set[TransSymbol](set[TransSymbol]) merge) {
    rel[&T, TransSymbol, &T] newTransitions = {};
    transitions = n.transitions<0, 2, 1>;
    for(from <- transitions<0>) {
        fromTransitions = transitions[from];
        for(to <- fromTransitions<0>) {
            fromToTransitions = fromTransitions[to];
            merged = merge(fromToTransitions);
            for(on <- merged) {
                newTransitions += <from, on, to>;
            }
        }
    }

    return <
        n.initial,
        newTransitions,
        n.accepting,
        ()
    >;
}

set[TransSymbol] PSNFAMerge(set[TransSymbol] symbols){
    disjoint = PSNFADisjoint(symbols)<0>;

    rel[TagClass, TransSymbol] indexedByTC = {<tc, s> | s:character(_, tc) <- disjoint};
    for(tc <- indexedByTC<0>) {
        tcSymbols = indexedByTC[tc];

        CharClass union = [];
        for(s:character(cc, _) <- tcSymbols) {
            disjoint -= s;
            union = fUnion(union, cc);
        }

        disjoint += character(cc, tc);
    }

    return disjoint;
}