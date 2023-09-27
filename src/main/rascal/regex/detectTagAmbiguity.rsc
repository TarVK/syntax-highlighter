module regex::detectTagAmbiguity

import Relation;
import Set;
import List;
import util::Maybe;

import regex::Tags;
import regex::NFA;
import regex::NFATypes;
import regex::PSNFA;
import regex::NFACombinators;
import regex::PSNFATypes;
import regex::PSNFACombinators;
import regex::NFASimplification;
import regex::util::charClass;
import regex::util::expandEpsilon;

@doc {
    Checks whether the given nfa n is tag-ambiguous. I.e. whether it can assign some word multiple different tags. 

    NOte that if in the implementation `just(_)` is returned, this corresponds to ambiguity having been detected. The value being returned is just extra information to help visualize the ambiguity to pinpoint the issue. 
}
bool isTagAmbiguous(NFA[State] n) = just(_) := getTagAmbiguity(n);
Maybe[NFA[tuple[set[&T], set[&T]]]()] getTagAmbiguity(NFA[State] n) {
    // D only has deterministic routes, leading to accepting states
    d = removeUnreachable(convertPSNFAtoDFA(n));

    // Check if there's a transition `u-a->v` where `a` is paired with multiple choices of tags
    if(tr:<_, character(_, t), _> <- d.transitions, size(t)>1) 
        return just(getPathPassingThroughProdGetter(d, {tr}));
    if(
        from <- d.transitions<0>,
        tr1:<on1:character(cc1, tags1), to> <- d.transitions[from], 
        tr2:<on2:character(cc2, tags2), to> <- d.transitions[from], 
        tr1!=tr2,
        size(fIntersection(cc1, cc2))>0,
        size(union(tags1, tags2))>1
    ) 
        return just(getPathPassingThroughProdGetter(d, {<from, on1, to>, <from, on2, to>}));
    
    // Remove all tags, and check for ambiguity in the resulting NFA
    taglessN = replaceTagsClasses(d, {{}});
    return getAmbiguity(taglessN, true);
}

@doc {
    Checks whether the given NFA has some word for which there exist multiple paths to accepting states, assuming the NFA is epsilon free. 

    isTrim can be set to true if the NFA has no unreachable/dead states, or if we don't care about ambiguity in these states.
}
bool isAmbiguous(NFA[&T] n) = just(_) := getAmbiguity(n, false); 
Maybe[NFA[tuple[&T, &T]]()] getAmbiguity(NFA[&T] n, bool isTrim) {
    /*
        Approach taken from (p75): https://www.cambridge.org/core/books/elements-of-automata-theory/B0E8167097AF9B70289FAE66A3147438

        Create the product automaton of `n`, and if there exists a path from initial state to final state that passes a state <q1, q2> where q1!=q2, then there are 2 distinct routes accepting the same word. 

        Also if the automaton is not trim (has unreachable/dead states), we also have to check whether there's a path from any state to any other state (not necessarily on the path from start to final states) that pass through 2 distinct states. If this is the case, the automaton is ambiguous. Note that this second step does not cover the scenario of reaching 2 distinct final states, hence the first step described above is also necessary. 
    */
    n2 = productNFA(n, n);

    n2Trimmed = removeUnreachable(n2); // Trim
    hasMultiplePaths = any(<q1, q2> <- getStates(n2Trimmed), q1 != q2);
    if(hasMultiplePaths) return just(getAmbiguousPathGetter(n2Trimmed));

    // IF we know the input is trim already, we can skip the second step
    if(isTrim) return nothing();

    selfStates = {<q, q> | q <- getStates(n2)};
    n2DiagonalTrimmed = removeUnreachable(n2, selfStates, selfStates); // Trim
    hasMultiplePaths = any(<q1, q2> <- getStates(n2DiagonalTrimmed), q1 != q2);
    if(hasMultiplePaths) return just(getAmbiguousPathGetter(n2DiagonalTrimmed));

    return nothing();
}

NFA[tuple[&T, &T]] productNFA(NFA[&T] n1, NFA[&T] n2) {
    Maybe[TransSymbol] matcher(TransSymbol on1, TransSymbol on2) {
        if(matchStart() == on1 && matchStart() == on2) return just(matchStart());
        if(matchEnd() == on1 && matchEnd() == on2) return just(matchEnd());
        if(character(cc1, t1) := on1 && character(cc2, t2) := on2) {
            cc = fIntersection(cc1, cc2);
            if(size(cc)<=0) return nothing();
            t = intersection(t1, t2);
            if(size(t)<=0) return nothing();
            return just(character(cc, t));
        }
        return nothing();
    }
    return productNFA(n1, n2, matcher);
}


// Utils for getting information about the found ambiguity
@doc {
    Removes everything except the ambiguous paths within an ambiguity NFA obtained from `getAmbiguity`
}
NFA[tuple[&T, &T]]() getAmbiguousPathGetter(NFA[tuple[&T, &T]] ambiguityNFA) 
    = NFA[tuple[&T, &T]]() { return getAmbiguousPath(ambiguityNFA); };
NFA[tuple[&T, &T]] getAmbiguousPath(NFA[tuple[&T, &T]] n) {
    ambiguityStates = {<q1, q2> | <q1, q2> <- getStates(n), q1 != q2};

    rel[tuple[&T, &T], TransSymbol, tuple[&T, &T]] outTrans = {};

     // Forward search
    set[tuple[&T, &T]] queue = ambiguityStates;
    set[tuple[&T, &T]] reachableForward = queue;
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);
        trans = n.transitions[state];
        outTrans += {<state, on, to> | <on, to> <- trans};

        toStates = trans<1>;
        newToStates = toStates - reachableForward;
        reachableForward += newToStates;
        queue += newToStates;
    }

    // Backward search
    revTransitions = n.transitions<2, 1, 0>;
    queue = ambiguityStates;
    set[tuple[&T, &T]] reachableBackward = queue;
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);
        trans = revTransitions[state];
        outTrans += {<from, on, state> | <on, from> <- trans};

        fromStates = trans<1>;
        newFromStates = fromStates - reachableBackward;
        reachableBackward += newFromStates;
        queue += newFromStates;
    }

    return <
        n.initial,
        outTrans,
        n.accepting & reachableForward,
        ()
    >;
}

@doc {
    Removes everything except the paths passing through one of the given transitions
}
NFA[&T]() getPathPassingThroughGetter(NFA[&T] n, rel[&T, TransSymbol, &T] through)
    = NFA[&T](){ return getPathPassingThrough(n, through); };
NFA[tuple[&T, &T]]() getPathPassingThroughProdGetter(NFA[&T] n, rel[&T, TransSymbol, &T] through)
    = NFA[&T](){ 
        NFA[tuple[&T, &T]] n2 = mapStates(n, tuple[&K, &K](&K s) {
            return <s, s>;
        });
        return getPathPassingThrough(n2, through); 
      };
NFA[&T] getPathPassingThrough(NFA[&T] n, rel[&T, TransSymbol, &T] through) {
    rel[&T, TransSymbol, &T] outTrans = through;

     // Forward search
    set[&T] queue = through<2>;
    set[&T] reachableForward = queue;
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);
        trans = n.transitions[state];
        outTrans += {<state, on, to> | <on, to> <- trans};

        toStates = trans<1>;
        newToStates = toStates - reachableForward;
        reachableForward += newToStates;
        queue += newToStates;
    }

    // Backward search
    revTransitions = n.transitions<2, 1, 0>;
    queue = through<0>;
    set[&T] reachableBackward = queue;
    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);
        trans = revTransitions[state];
        outTrans += {<from, on, state> | <on, from> <- trans};

        fromStates = trans<1>;
        newFromStates = fromStates - reachableBackward;
        reachableBackward += newFromStates;
        queue += newFromStates;
    }

    return <
        n.initial,
        outTrans,
        n.accepting & reachableForward,
        ()
    >;
}


// Old approach I came up with, which may or may not work:
// bool isAmbiguous(NFA[&T] n) = isAmbiguous(n, true);
// bool isAmbiguous(NFA[&T] n, bool canHaveEpsilon) {
//     // TODO: consider implementing the approach as disccused in this book (p75): https://www.cambridge.org/core/books/elements-of-automata-theory/B0E8167097AF9B70289FAE66A3147438

//     // Remove dead states from n such that no irrelevant transitions/states are considered
//     n = removeUnreachable(n);

//     // D only has deterministic routes, leading to accepting states
//     d = removeUnreachable(convertPSNFAtoDFA(n));

//     // Check if d has states containing multiple accepting states of n, this indicates multiple (distinct) final states of n can be reached with the same word. Hence n is ambiguous. 
//     if(S <- d.accepting, size(S) > 1) return true;

//     // Check if there are distinct states of n for the same prefix, which lead to the same state of n. If this is the case, there's multiple routes to acceptance
//     trans = index(n.transitions);
//     for(S <- d.acceptance) {
//         if(!canHaveEpsilon){
//             if(
//                 {<_, on1, to>, <_, on2, to>, *_} := trans[S],
//                 overlap(on1, on2)
//             ) return true;
//         } else {
//             // If the automaton can have epsilon transitions, we have to consider that we might only reach the same state after several epsilon steps
//             rel[&T, TransSymbol, set[&T]] SOutMap = {
//                 <from, on, expandEpsilon(n, {to})> |
//                 from <- S,
//                 <on, to> <- trans[s]
//             };

//             if(
//                 {<_, on1, to1>, <_, on2, to2>, *_} := SOutMap,
//                 size(to1 & to2) > 0,
//                 overlap(on1, on2)
//             ) return true;
//         }
//     }

//     // If none of these things happened, the automaton is unambiguous
//     return false;
// }