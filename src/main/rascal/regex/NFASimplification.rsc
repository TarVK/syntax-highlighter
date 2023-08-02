module regex::NFASimplification

import Set;
import IO;
import ParseTree;

import regex::NFA;
import regex::PSNFA;
import regex::Tags;
import regex::util::expandEpsilon;
import regex::util::GetDisjointCharClasses;


@doc {
    Minimizes the given NFA using a DFA minimization algorithm, nad gets rid of unreachable/dead states.
}
NFA[set[&T]] minimize(NFA[&T] nfa) {
    TagsClass universe = {*tc | <_, character(_, tc), _> <- nfa.transitions};
    dfa = convertPSNFAtoDFA(removeUnreachable(nfa), universe);
    minimizedDFA = minimizeDFA(dfa);

    flattenedMinimizedDFA = mapStates(minimizedDFA, set[&T] (set[set[&T]] states) {
        return {*state | state <- states};
    });

    return removeUnreachable(flattenedMinimizedDFA);
}

@doc {
    Minimizes the given DFA using a DFA minimization algorithm, but does not get rid of unreachable/dead states.
    Hence this requires the input to be a valid DFA!
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

    set[set[&T]] P = {getStates(n) - n.accepting, n.accepting};
    set[set[&T]] W = P;

    while (size(W) > 0) {
        <A, W> = takeOneFrom(W);

        inComing = reverseEdges[A];
        transSymbols = inComing<0>;
        for(transSymbol <- transSymbols) {
            X = inComing[transSymbol];
            for(set[&T] Y <- P) {
                intersect = (X & Y);
                assymDifference = Y - X;
                if(size(intersect)>0 && size(assymDifference)>0) {
                    P = (P - {Y}) + {intersect} + {assymDifference};
                    if (Y in W)
                        W = (W - {Y}) + {intersect} + {assymDifference};
                    else if (size(intersect) < size(assymDifference))
                        W += {intersect};
                    else
                        W += {assymDifference};
                }
            }
        }
    }

    return P;
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

            toSet = expandEpsilon(n, {to});
            init(toSet);
            transitions += <setOfStates, sym, toSet>;
        }
    }

    accepting = {setOfStates | setOfStates <- found && size(setOfStates & n.accepting)>0};

    return <initial, transitions, accepting, ()>;
}

@doc {
    Removes all states from the NFA that are not reachable from initial state to accepting state
}
NFA[&T] removeUnreachable(NFA[&T] n) {
    // Forward search
    set[&T] queue = {n.initial};
    set[&T] reachableInitial = queue;
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);
        toStates = n.transitions[state]<1>;
        newToStates = toStates - reachableInitial;
        reachableInitial += newToStates;
        queue += newToStates;
    }

    // Backward search
    revTransitions = n.transitions<2, 1, 0>;
    queue = n.accepting;
    set[&T] reachableAccepting = queue;
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);
        fromStates = revTransitions[state]<1>;
        newFromStates = fromStates - reachableAccepting;
        reachableAccepting += newFromStates;
        queue += newFromStates;
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