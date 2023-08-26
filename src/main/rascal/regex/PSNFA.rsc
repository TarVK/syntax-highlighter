module regex::PSNFA
extend regex::NFA;
extend regex::PSNFATypes;

import util::Maybe;
import String;
import Set;
import IO;
import ParseTree;
import Relation;

import Visualize;
import Scope;
import regex::NFASimplification;
import regex::util::GetDisjointCharClasses;
import regex::Regex;
import regex::Tags;
import regex::NFA;
import regex::DFA;
import regex::PSNFATypes;

@doc{
    Checks whether the given prefix, text, and suffix is within the PSNFA's language
}
bool matches(NFA[&T] n, tuple[str, str, str] text) {
    chars = [];
    for(index <- [0..size(text[0])]) chars += characterL(charAt(text[0], index));
    chars += matchStartL();
    for(index <- [0..size(text[1])]) chars += characterL(charAt(text[1], index));
    chars += matchEndL();
    for(index <- [0..size(text[2])]) chars += characterL(charAt(text[2], index));
    return matches(n, chars, PSNFAMatch);
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
NFA[set[&T]] convertPSNFAtoDFA(NFA[&T] n) 
    = convertPSNFAtoDFA(n, tagsUniverse(n));
NFA[set[&T]] convertPSNFAtoDFA(NFA[&T] n, TagsClass tagsUniverse) {
    PSNFAComplement = getPSNFAComplementRetriever(tagsUniverse);
    return convertNFAtoDFA(n, PSNFADisjoint, PSNFAComplement);
}
TagsClass tagsUniverse(NFA[&T] n) = {*tagsClass | character(char, tagsClass) <- n.transitions<1>};

rel[TransSymbol, TransSymbol] PSNFADisjoint(set[TransSymbol] symbols) {
    set[tuple[TransSymbol, TransSymbol]] out = {
        <symbol, symbol> | symbol <- symbols, character(_, _) !:= symbol
    };

    rel[CharClass, TagsClass, CharClass] chars = {<charClass, tagClass, charClass> | character(charClass, tagClass) <- symbols};
    disjointCharClasses = getDisjointCharClasses(chars<0>);
    for(ccr(disjointCharClass, orCharClasses) <- disjointCharClasses) {
        tagClasses = chars[orCharClasses];
        disjointTagsClasses = getDisjointTagsClasses(tagClasses<0>);
        for(tcr(disjointTagsClass, orTagsClasses) <- disjointTagsClasses) {
            out += {<
                character(disjointCharClass, disjointTagsClass), 
                character(orCharClass, orTagsClass)
            > | orTagsClass <- orTagsClasses, orCharClass <- tagClasses[{orTagsClass}]}; // {orTagsClass} because set indexing is incorrectly used otherwise
        }
    }

    return out;
}
set[TransSymbol](set[TransSymbol] included) getPSNFAComplementRetriever(TagsClass tagsUniverse) 
    = set[TransSymbol](set[TransSymbol] included){
        set[TransSymbol] out = {matchStart(), matchEnd()} - included;

        // For the included characters, calculate the remaining tags
        rel[CharClass, TagsClass] chars = {<charClass, tagClass> | character(charClass, tagClass) <- included};
        for(cc <- chars<0>) {
            tagClasses = chars[cc];
            restTagsClass = complement(({} | union(it, tc) | tc <- tagClasses), tagsUniverse);
            if(!isEmpty(restTagsClass)) out += character(cc, restTagsClass);
        }
        
        // Calculate the remaining characters
        CharClass remainingChars = getCharsComplements({cc | character(cc, _) <- included});
        if(size(remainingChars)>0)
            out += character(remainingChars, complement({}, tagsUniverse)); // The remaning characters with any tags

        return out;
    };

@doc {
    Retrieves the prefix states, main states, and suffix states of the given PSNFA
}
tuple[set[&T], set[&T], set[&T]] getPSNFApartition(NFA[&T] n) {
    set[&T] prefixStates = {};
    set[&T] mainStates = {};
    set[&T] suffixStates = {};

    set[&T] reached = {};

    set[tuple[StateType, &T]] queue = {<prefixState(), n.initial>};
    while(size(queue)>0) {
        <stateAndType, queue> = takeOneFrom(queue);
        <sType, state> = stateAndType;
        
        if(state in reached) continue;
        reached += {state};

        if(sType == prefixState()) prefixStates += {state};
        else if(sType == mainState()) mainStates += {state};
        else if(sType == suffixState()) suffixStates += {state};

        for(<trans, to> <- n.transitions[state]) {
            if(trans == matchStart()) queue += <mainState(), to>;
            else if(trans == matchEnd()) queue += <suffixState(), to>;
            else queue += <sType, to>;
        }
    }

    return <prefixStates, mainStates, suffixStates>;
}
data StateType = prefixState() | mainState() | suffixState();

@doc {
    A function to visualize PSNFAs by outputing a string that can be rendered by the following website:
    https://dreampuf.github.io/GraphvizOnline
}
str visualizePSNFA(NFA[&T] n) = visualizePSNFA(n, Maybe[str](TransSymbol _) { return nothing(); });
str visualizePSNFA(NFA[&T] n, Maybe[str](TransSymbol sym) getLabel) = 
    visualize(n, getPSNFALabeler(getLabel));

Maybe[str](TransSymbol sym) getPSNFALabeler(Maybe[str](TransSymbol sym) getLabel) 
    = Maybe[str](TransSymbol sym){
        str getTags(TagsClass tc) = regex::Tags::stringify({{scopeTag(scopes) := t ? stringify(scopes) : t | t <- tags} | tags <- tc});

        if(just(l) := getLabel(sym)) return just(l);
        if(sym == matchStart()) return just("(|");
        if(sym == matchEnd()) return just("|)");
        if(character([range(1,0x10FFFF)], tagClass) := sym) return just("*:"+getTags(tagClass));
        if(character(charClass, tagClass) := sym) return just(stringify(charClass)+":"+getTags(tagClass));
        return nothing();
    };

@doc {
    Converts a PSNFA to a diagram that can be shown using Rascal-vis (https://github.com/TarVK/rascal-vis)
}
RascalVisGraph PSNFAtoDiagram(NFA[&T] n) = PSNFAtoDiagram(n, Maybe[str](TransSymbol _){ return nothing(); });
RascalVisGraph PSNFAtoDiagram(NFA[&T] n, Maybe[str](TransSymbol sym) getLabel) = toDiagram(n, getPSNFALabeler(getLabel));

@doc {
    Converts attaches diagrams to all internal PSNFAs, in order to be visualized using Rascal-vis (https://github.com/TarVK/rascal-vis)
    Note that this only works with PSNFAs using the `State` type, E.g. generated from the PSNFA combinators.
}
value insertPSNFADiagrams(value val) = insertPSNFADiagrams(val, true);
value insertPSNFADiagrams(value val, bool simplify) = top-down-break visit (val) {
    case n:<State i, rel[State, TransSymbol, State] t, set[State] a, _> => simplify 
        ? <i, t, a, PSNFAtoDiagram(relabel(n))>
        : <i, t, a, PSNFAtoDiagram(n)>
};

@doc {
    Relabels all states of the given NFA to a numeric one
}
NFA[int] relabel(NFA[&T] n) {
    maxID = 0; 
    set[&T] found = {};
    set[&T] queue = {n.initial};
    map[&T, int] labels = ();

    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);

        if(state in found) continue;
        found += {state};

        labels[state] = maxID;
        maxID += 1;

        queue += n.transitions[state]<1>;
    }

    int mapState(&T state) {
        if (state in labels) return labels[state];
        maxID += 1;
        return maxID-1;
    }

    return mapStates(n, mapState);
}