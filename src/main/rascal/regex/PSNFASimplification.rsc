module regex::PSNFASimplification

import IO;
import ParseTree;
import Set;
import List;
import Relation;

import regex::util::GetDisjointCharClasses;
import regex::util::charClass;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFATypes;
import regex::NFASimplification;
import regex::Tags;



@doc {
    Turns the PSNFA containing sets of states into a PSNFA with State instances, to be reusable in other PSNFA combinators
}
NFA[State] relabelSetPSNFA(NFA[set[State]] n) = mapStates(n, State (set[State] states) { return stateSet(states); });

@doc {
    Turns the PSNFA containing int states into a PSNFA with State instances, to be reusable in other PSNFA combinators
}
NFA[State] relabelIntPSNFA(NFA[int] n) = mapStates(n, State (int state) { return simple(state); });

@doc {
    Minimizes the given NFA, and ensures uniqueness such that every other NFA with the same language obtained from this function, is fully identical. 
}
NFA[State] minimizeUnique(NFA[State] n) {
    PSNFAComplement = getPSNFAComplementRetriever(tagsUniverse(n));

    minimized = minimize(n, PSNFADisjoint, PSNFAComplement);
    normalizedEdges = normalizePSNFAEdges(minimized);
    normalized = normalizePSNFAStates(normalizedEdges, State(set[set[State]] state){
        return stateSet({stateSet(s) | s <- state});
    });
    return normalized;
}

@doc {
    Normalizes the edges of the PSNFA, such that for every two states u,v: 
    - ∀ u-character(cc, tc)->v.
        . |cc| > 0 ∧ |tc| > 0 
    - ∀ u-character(cc1, tc1)->v, u-character(cc2, tc2)->v
        . tc1 ∩ tc2 = ∅ ∧ cc1 != cc2
}
NFA[&T] normalizePSNFAEdges(NFA[&T] n) {
    map[&T, set[tuple[&T, TransSymbol]]] partiallyIndexedTransitions 
        = Relation::index({<from, <to, on>> | <from, on, to> <- n.transitions});
    map[&T, map[&T, set[TransSymbol]]] indexedTransitions 
        = (from: Relation::index(partiallyIndexedTransitions[from]) | from <- partiallyIndexedTransitions);

    rel[&T, TransSymbol, &T] out = {};
    for(from <- indexedTransitions) {
        indexedFromTransitions = indexedTransitions[from];
        for(to <- indexedFromTransitions) {
            onSet = indexedFromTransitions[to];
            for(on <- normalizePSNFAEdges(onSet)) {
                out += <from, on, to>;
            }
        }
    }

    return <n.initial, out, n.accepting, ()>;
}
set[TransSymbol] normalizePSNFAEdges(set[TransSymbol] symbols) {
    characterDefs = {cd | cd:character(_, _) <- symbols};
    symbols -= characterDefs;
    
    rel[TagsClass, CharClass] indexedTcCC = {<tc, cc> | character(cc, tc) <- characterDefs};

    // Make sure there's no overlap between tag-classes
    rel[CharClass, TagsClass] indexedCcDisjointTC = {};
    for(tcr(tc, includes) <- getDisjointTagsClasses(indexedTcCC<0>)){
        charClasses = indexedTcCC[includes];
        if({firstCC, *restCC} := charClasses) {
            charClass = (firstCC | fUnion(it, cc) | cc <- restCC);

            if(size(charClass)>0 && size(tc)>0)
                indexedCcDisjointTC += {<charClass, tc>};
        }
    }

    // Make sure there are no duplicate character classes
    for(cc <- indexedCcDisjointTC<0>) {
        tagClasses = indexedCcDisjointTC[cc];
        if({firstTC, *restTC} := tagClasses) {
            tagClass = (firstTC | union(it, tc) | tc <- restTC);
            symbols += character(normalize(cc), tagClass);
        }
    }

    return symbols;
}

/*
    Consider character(cc, ct) to be a "character definition".
    Let C be the universe of characters (a, b, c, etc)
    Let T be the universe of tagsets ({smth}, {smth, more})
    Let CC = P(C), the universe of character classes
    Let TC = P(T), the universe of tagset classes
    Let CD be the universe of all possible character(cc, tc) definitions
    Let CDS = P(CD), I.e. the universe of all possible character(cc, tc) sets that are normalized

    Let L(character(cc, tc)) = cc ⨯ tc  (cc ∈ CC, tc ∈ TC)
    Let L({character(cc, tc), *rest}) = L(character(cc, tc)) ∪ L(rest)
        L(∅) = ∅

    Let `F(t, character(cc, tc)) = {c | (c, t) ∈ L(character(cc, tc))}
    Lemma 1: ∀ s1, s2 ∈ CDS. L(s1) = L(s2) => 
            ∀ t ∈ T, character(cc1, tc1) ∈ s1. (∃ c ∈ C. (t,c) ∈ L(character(cc1, tc1))) => 
                ∃ character(cc2, tc2) ∈ s2. F(t, character(cc1, tc1)) = F(t, character(cc2, tc2)) ∧ cc1 == cc2`:
        I.e. for every character definition sets with an equivalent language and every tagset, if there is a character definition with this tagset in one character set, there is one with a character definition with an equivalent character class in the other character set.

        Prove:
        Consider arbitrary s1, s2 ∈ CDS, t ∈ T, character(cc1, tc1) ∈ s1 meet all the conditions. 
        let c ∈ C be a character such that `(t,c) ∈ L(character(cc1, tc1))`.
        Then because `(t,c) ∈ L(s2)` and `L(s1) = L(s2)` there `∃ character(cc2, tc2) ∈ s2 . (t, c) ∈ L(s2)`. 
        Let character(cc2, tc2) be this value.
        We know that `F(character(cc1, tc1)) ⊆ F(character(cc2, tc2))`:
            Assume this isn't the case, then `∃ c2 ∈ F(character(cc1, tc1)). ¬(c2 ∈ F(character(cc2, tc2)))`. 
            But all items paired with tagset t can only come from `F(character(cc2, tc2))`, 
            thus then we must have `¬((t, c2) in L(s2))`.
            But then `L(s1) != L(s2)`, which contradicts our initial assumptions.
        Symmetrically we can argue that `F(character(cc2, tc2)) ⊆ F(character(cc1, tc1))`.
        Thus `F(character(cc1, tc1)) = F(character(cc2, tc2))`, and hence we must have that `cc1 = cc2`. 


    Uniqueness: `∀ s1,s2 ∈ CDS. L(s1) = L(s2) => s1 = s2`
        Prove prove by contradiction:
        Assume that for arbitrary character sets s1 and s2, `L(s1) = L(s2) ∧ s1 != s2`.

        Then WLOG assume `∃ character(cc1, tc1) ∈ s1 . ¬(character(cc1, tc1) ∈ s2)`.

        Let t be an arbitrary tagset in tc1, then by lemma 1, we know that there exists a `character(cc2, tc2) ∈ s2`, such that `cc1 = cc2`.
        This means that `tc1 != tc2`, or else `character(cc1, tc1) ∈ s2`. 
        WLOG assume `∃ t2 ∈ tc1 . ¬(t2 ∈ tc2)`.
        Then by lemma 1, we know that there exists a `character(cc2', tc2') ∈ s2`, such that `cc1 = cc2'`.
        However that means by transtivity, that `cc2 = cc2'`. 
        Now if `¬(t2 in tc2) ∧ t2 ∈ tc2'` we know that `tc2 != tc2'`. Hence we have two distinct character transitions in s2 with the same character class. 
        This contradicts our normalization assumption: `∀ u-character(cc1, tc1)->v, u-character(cc2, tc2)->v. cc1 != cc2`
        Hence we reached a contradiction. 
*/

@doc {
    Relabels all states of the NFA such that every state by identifiers, such that the identifiers are fully determined by the structure of the transitions. This then serves as a normalization step for the states if the nfa is deterministic.

    Note this only works properly if all provided tags are comparable using rascal's `<` operator such that `a < b || a > b || a == b` always holds. This means that tags can't contain sets, lists, relations, or maps. 
}
NFA[State] normalizePSNFAStates(NFA[&T] nfa, State(&T) createState) {
    int i = 0;
    map[&T, State] relabeling = (nfa.initial: simple(0));

    list[&T] queue = [nfa.initial];
    set[&T] reached = {nfa.initial};

    while([state, *rest] := queue) {
        queue = rest;

        map[TransSymbol, set[&T]] stateTransitions = Relation::index(nfa.transitions[{state}]);
        // Sort to make sure the order is consistent and fully based on the transition symbols
        list[TransSymbol] transitionsSymbols = sort(stateTransitions<0>, lessThan);
        for(transSym <- transitionsSymbols) {
            toStates = stateTransitions[transSym];

            // Assuming there is only one state this transition goes to, this ordering is irrelevant
            for(toState <- toStates) {
                if(toState notin reached) {
                    reached += {toState};
                    queue += toState;
                    i = i+1;
                    relabeling[toState] = simple(i);
                }
            }
        }
    }

    return mapStates(nfa, State(&T oldState) {
        if(oldState in relabeling)
            return relabeling[oldState];
        return stateLabel("unreachable", createState(oldState));
    });
}

@doc {
    A transition symbol compare function that considers both the character and tagclasses. This only works if all tags provided in tag classes are comparable using `<`. 
}
bool lessThan(TransSymbol a, TransSymbol b) {
    // Use rascal constructor ordering for different types
    if(a < b) return true;
    if(a > b) return false;

    // Use custom ordering for characters
    if(character(ccA, tcA) := a, character(ccB, tcB) := b) {
        if(ccA != ccB) return smallerList(ccA, ccB);
        if(tcA == tcB) return false;

        // Order based on tagclasses, what the order is is not relevant, as long as it can differentiate different tag classes consistently. 
        list[list[value]] getOrderData(set[set[value]] tagsClass) {
            valLists = [[*tags] | tags <- tagsClass];
            list[list[value]] innerSorted = [sort(valList) | valList <- valLists];
            outerSorted = sort(innerSorted, bool(list[value] la, list[value] lb) {
                if(la==lb) return false;
                return smallerList(la, lb);
            });
            return outerSorted;
        }

        sortedTagsClassesA = getOrderData(tcA);
        sortedTagsClassesB = getOrderData(tcB);
        return smallerList(sortedTagsClassesA, sortedTagsClassesB, bool(list[value] la, list[value] lb) {
            if(la==lb) return false;
            return smallerList(la, lb);
        });   
    }

    return a < b;
}

bool smallerList(list[value] la, list[value] lb) 
    = smallerList(la, lb, bool(value va, value vb){ return va<vb; });
bool smallerList(list[&T] la, list[&T] lb, bool(&T va, &T vb) lt) {
    for(i <- [0..size(la)]) {
        if(i >= size(lb)) return false;
        if(lt(la[i], lb[i])) return true;
        if(lt(lb[i], la[i])) return false;
    }
    return true;
}
