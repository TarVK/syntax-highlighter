module regex::PSNFA

import regex::NFA;
import regex::DFA;
import String;
import Set;

data TransSymbol = matchStart()
                 | matchEnd();

@doc{
    Checks whether the given prefix, text, and suffix is within the PSNFA's language
}
bool matches(NFA[&T] nfa, tuple[str, str, str] text) {
    chars = [];
    for(index <- [0..size(text[0])]) chars += char(charAt(text[0], index));
    chars += literal(matchStart());
    for(index <- [0..size(text[1])]) chars += char(charAt(text[1], index));
    chars += literal(matchEnd());
    for(index <- [0..size(text[2])]) chars += char(charAt(text[2], index));
    return matches(nfa, chars);
}

@doc {
    Converts the given PSNFA to a deterministic PSNFA with an equivalent language
}
NFA[set[&T]] convertPSNFAtoDFA(NFA[&T] nfa) = convertNFAtoDFA(nfa, PSNFAComplement);
set[TransSymbol] PSNFAComplement(set[TransSymbol] included) = {matchStart(), matchEnd()} - included;

@doc {
    Retrieves the prefix states, main states, and suffix states of the given PSNFA
}
tuple[set[&T], set[&T], set[&T]] getPSNFApartition(NFA[&T] n) {
    set[&T] prefixStates = {};
    set[&T] mainStates = {};
    set[&T] suffixStates = {};

    set[&T] reached = {};

    set[tuple[StateType, &T]] queue = {<prefix(), n.initial>};
    while(size(queue)>0) {
        <stateAndType, queue> = takeOneFrom(queue);
        <sType, state> = stateAndType;
        
        if(state in reached) continue;
        reached += {state};

        if(sType == prefix()) prefixStates += {state};
        else if(sType == main()) mainStates += {state};
        else if(sType == suffix()) suffixStates += {state};

        for(<trans, to> <- n.transitions[state]) {
            if(trans == matchStart()) queue += <main(), to>;
            else if(trans == matchEnd()) queue += <suffix(), to>;
            else queue += <sType, to>;
        }
    }

    return <prefixStates, mainStates, suffixStates>;
}
data StateType = prefix() | main() | suffix();