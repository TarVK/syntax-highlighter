module regex::PSNFA

import regex::NFA;
import regex::DFA;
import String;

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