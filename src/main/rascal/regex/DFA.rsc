module regex::DFA

import Set;
import List;
import ParseTree;

import regex::util::GetDisjointCharClasses;
import regex::NFA;

alias ComputeRemainder = set[TransSymbol](set[TransSymbol]);
alias ComputeDisjoint = set[tuple[TransSymbol, TransSymbol]](set[TransSymbol]);

@doc {
    Converts a NFA to an equivalent NFA that satisfies all DFA restrictions (no epsilon transitions, and complete)
}
NFA[set[&T]] convertNFAtoDFA(NFA[&T] nfa) = convertNFAtoDFA(nfa, defaultDisjoint, defaultComplement);
NFA[set[&T]] convertNFAtoDFA(NFA[&T] nfa, ComputeDisjoint getDisjoint, ComputeRemainder getRemainder) {
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
        
        transitions = nfa.transitions[stateSet];
        transitionSymbols = {symbol <- transitions<0>, symbol != epsilon()};

        disjoinSymbolsMapping = getDisjoint(transitionSymbols);
        for(<disjoint, original> <- disjoinSymbolsMapping) {
            directToSet = transitions[original];
            toSet = expandEpsilon(directToSet);
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

    accepting = {stateSet | stateSet <- found && size(stateSet & nfa.accepting)>0};

    return <initial, transitions, accepting>;
}

@doc {
    The default transition complement retriever
}
set[TransSymbol] defaultComplement(set[TransSymbol] symbols) = character(getCharsComplements({cc | character(cc) <- symbols}));

@doc {
    A function to get the complement of a set of character classes
}
CharClass getCharsComplements(set[CharClass] ccs) = fComplement(([] | fUnion(it, cc) | cc <- ccs));

@doc {
    The default disjoint transition symbol retriever
}
set[tuple[TransSymbol, TransSymbol]] defaultDisjoint(set[TransSymbol] symbols) {
    set[tuple[TransSymbol, TransSymbol]] out = {
        <symbol, symbol> | symbol <- symbols, character(_) !:= symbols
    };

    disjointCharClasses = getDisjointCharClasses({ charClass | character(charClass) <- symbols});
    for(ccr(disjointClass, orSet) <- disjointCharClasses) 
        out += {<character(disjointClass), character(or)> | or <- orSet};

    return out;
}

