module regex::DFA

import Set;
import List;
import ParseTree;

import regex::util::GetDisjointCharClasses;
import regex::NFATypes;
import regex::util::expandEpsilon;

alias ComputeRemainder = set[TransSymbol](set[TransSymbol]);
alias ComputeDisjoint = set[tuple[TransSymbol, TransSymbol]](set[TransSymbol]);

// TODO: since exponential blow-ups are possible, it would be smart to add some max-iteration system such that we can throw an error and point towards related areas in the grammar, instead of just hanging. 

@doc {
    Converts a NFA to an equivalent NFA that satisfies all DFA restrictions (no epsilon transitions, and complete)
}
NFA[set[&T]] convertNFAtoDFA(NFA[&T] n) = convertNFAtoDFA(n, defaultDisjoint, defaultComplement);
NFA[set[&T]] convertNFAtoDFA(NFA[&T] n, ComputeDisjoint getDisjoint, ComputeRemainder getRemainder) {
    initial = expandEpsilon(n, {n.initial});
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
        
        stateTransitions = n.transitions[stateSet];
        transitionSymbols = {symbol | symbol <- stateTransitions<0>, symbol != epsilon()};

        disjoinSymbolsMapping = getDisjoint(transitionSymbols);
        for(<disjoint, original> <- disjoinSymbolsMapping) {
            directToSet = stateTransitions[original];
            set[&T] toSet = expandEpsilon(n, directToSet);
            init(toSet);
            transitions += <stateSet, disjoint, toSet>;
        }

        includedSymbols = disjoinSymbolsMapping<0>;
        remainingSymbols = getRemainder(includedSymbols);
        for(remainingSymbol <- remainingSymbols) {
            set[&T] toSet = {};
            init(toSet);
            transitions += <stateSet, remainingSymbol, toSet>;
        }
    }

    accepting = {stateSet | stateSet <- found && size(stateSet & n.accepting)>0};

    return <initial, transitions, accepting, ()>;
}

@doc {
    The default transition complement retriever
}
set[TransSymbol] defaultComplement(set[TransSymbol] transSymbols) {
    complementChars = getCharsComplements({cc | character(cc) <- transSymbols});
    if(size(complementChars)==0) return {};
    return {character(complementChars)};
}

@doc {
    A function to get the complement of a set of character classes
}
CharClass getCharsComplements(set[CharClass] ccs) = fComplement(([] | fUnion(it, cc) | cc <- ccs));

@doc {
    The default disjoint transition symbol retriever
}
set[tuple[TransSymbol, TransSymbol]] defaultDisjoint(set[TransSymbol] transymbols) {
    set[tuple[TransSymbol, TransSymbol]] out = {
        <symbol, symbol> | symbol <- transymbols, character(_) !:= symbol
    };

    disjointCharClasses = getDisjointCharClasses({ charClass | character(charClass) <- transymbols});
    for(ccr(disjointClass, orSet) <- disjointCharClasses) 
        out += {<character(disjointClass), character(or)> | or <- orSet};

    return out;
}

