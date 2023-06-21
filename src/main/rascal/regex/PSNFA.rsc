module regex::PSNFA

import String;
import Set;
import IO;
import ParseTree;
import Relation;

import regex::util::GetDisjointCharClasses;
import regex::Tags;
import regex::NFA;
import regex::DFA;

data TransSymbol = matchStart()
                 | matchEnd()
                 | character(CharClass char, TagClass tags);
data LangSymbol = matchStartL()
                | matchEndL()
                | characterL(int code, Tags tags);

@doc{
    Checks whether the given prefix, text, and suffix is within the PSNFA's language
}
bool matches(NFA[&T] nfa, tuple[str, str, str] text) {
    chars = [];
    for(index <- [0..size(text[0])]) chars += characterL(charAt(text[0], index));
    chars += matchStartL();
    for(index <- [0..size(text[1])]) chars += characterL(charAt(text[1], index));
    chars += matchEndL();
    for(index <- [0..size(text[2])]) chars += characterL(charAt(text[2], index));
    return matches(nfa, chars, PSNFAMatch);
}
bool PSNFAMatch(LangSymbol input, TransSymbol match) {
    if(epsilon() == match) return false;
    if(matchStartL() == input && matchStart() == match) return true;
    if(matchEndL() == input && matchEnd() == match) return true;
    if(characterL(charCode, tags) := input && character(ranges, tagOptions) := match) return contains(ranges, charCode) && contains(tagOptions, tags);
    return false;
}

@doc {
    Converts the given PSNFA to a deterministic PSNFA with an equivalent language
}
NFA[set[&T]] convertPSNFAtoDFA(NFA[&T] nfa) = convertNFAtoDFA(nfa, PSNFADisjoint, PSNFAComplement);

rel[TransSymbol, TransSymbol] PSNFADisjoint(set[TransSymbol] symbols) {
    set[tuple[TransSymbol, TransSymbol]] out = {
        <symbol, symbol> | symbol <- symbols, character(_, _) !:= symbol
    };

    rel[CharClass, TagClass, CharClass] chars = {<charClass, tagClass, charClass> | character(charClass, tagClass) <- symbols};
    disjointCharClasses = getDisjointCharClasses(chars<0>);
    for(ccr(disjointCharClass, orCharClasses) <- disjointCharClasses) {
        tagClasses = chars[orCharClasses];
        disjointTagClasses = getDisjointTagClasses(tagClasses<0>);
        for(tcr(disjointTagClass, orTagClasses) <- disjointTagClasses) {
            out += {<
                character(disjointCharClass, disjointTagClass), 
                character(orCharClass, orTagClass)
            > | orTagClass <- orTagClasses, orCharClass <- tagClasses[orTagClass]};
        }

    }

    return out;
}
set[TransSymbol] PSNFAComplement(set[TransSymbol] included) {
    set[TransSymbol] out = {matchStart(), matchEnd()} - included;

    // For the included characters, calculate the remaining tags
    rel[CharClass, TagClass] chars = {<charClass, tagClass> | character(charClass, tagClass) <- included};
    for(cc <- chars<0>) {
        tagClasses = chars[cc];
        restTagClass = complement((tags({}) | union(it, tc) | tc <- tagClasses));
        if(!isEmpty(restTagClass)) out += character(cc, restTagClass);
    }
    
    // Calculate the remaining characters
    CharClass remainingChars = getCharsComplements({cc | character(cc, _) <- included});
    out += character(remainingChars, notTags({})); // The remaning characters with any tags

    return out;
} 

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

void main() {
    input1 = {
        character([range(5, 10)], tags({{0}})),
        character([range(8, 10)], tags({{0}})),
        character([range(3, 8)], tags({{0, 2}})),
        character([range(2, 9)], notTags({{2}}))
    };
    input2 = {
        character([range(5, 10)], tags({{0}})),
        character([range(5, 10)], tags({{2}})),
        character([range(2, 9)], notTags({{2}, {3, 4}}))
    };
    disjoint = PSNFADisjoint(input2);
    println(index(disjoint));

    c = PSNFAComplement(input2);
    println(c);
}