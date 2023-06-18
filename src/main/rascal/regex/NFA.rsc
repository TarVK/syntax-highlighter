module regex::NFA

import String;
import util::Maybe;
import ParseTree;
import Set;

import regex::util::GetDisjointCharClasses;
import regex::Regex;

alias NFA[&T] = tuple[&T initial, rel[&T, TransSymbol, &T] transitions, set[&T] accepting];

data TransSymbol = character(CharClass char)
                 | rest()
                 | epsilon();
data LangSymbol = char(int code);

data MatchType = none() | match() | ifNoOther();
alias CharMatcher = MatchType(LangSymbol input, TransSymbol transition);



set[&T] getStates(NFA[&T] nfa) = nfa.transitions<0> + nfa.transitions<2> + {nfa.initial} + nfa.accepting;

@doc{
    Checks whether the given text is within the NFA's language
}
bool matches(NFA[&T] nfa, str text) {
    list[LangSymbol] chars = [];
    for(index <- [0..size(text)])
        chars += char(charAt(text, index));
    return matches(nfa, chars);
}
MatchType simpleMatch(LangSymbol input, TransSymbol match, bool matchedNoOthers) {
    if(epsilon() == match) return none();
    else if(rest() == match) return ifNoOther();
    else if(character(ranges) := match) return char(charCode) := input && contains(ranges, charCode) ? match() : none();
    return none();
}
bool matches(NFA[&T] nfa, list[LangSymbol] input, CharMatcher matcher) {
    states = expandEpsilon(nfa, {nfa.initial});

    for (symbol <- input) {
        newStates = {};
        for(state <- states) {
            transitions = nfa.transitions[state];

            set[&T] rest = {};
            bool matched = false;
            for(<match, to> <- transitions) {
                matchType = matcher(symbol, match, transitions);
                if (matchType==ifNoOther()) rest += {to};
                if (matchType!=match()) continue;
                newStates += to;
                matched = true;
            }

            if(!matched) newStates += rest;
        }
        states = expandEpsilon(nfa, newStates);
    }

    accepts = size(nfa.accepting & states)>0;
    return accepts;
}
set[&T] expandEpsilon(NFA[&T] nfa, set[&T] states) {
    added = states;
    while(size(added)>0) {
        newAdded = {};
        for(state <- added) {
            transitions = nfa.transitions[state];
            for(<epsilon(), to> <- transitions){
                if(to in states) continue;
                newAdded += {to};
                states += {to};
            }
        }
        added = newAdded;
    }
    return states;
}
bool contains(CharClass ranges, int char) {
    for(range(from, to) <- ranges)
        if(from <= char && char <= to) return true;
    return false;
}


@doc{
    Checks whether the given NFA's language is empty
}
bool isEmpty(NFA[&T] nfa) {
    added = {nfa.initial};
    reached = added;
    while(size(added)>0) {
        newAdded = {};
        for(state <- added) {
            transitions = nfa.transitions[state];
            for(<_, to> <- transitions){
                if(to in reached) continue;
                newAdded += to;
                reached += to;
            }
        }
        added = newAdded;
    }
    
    accepts = size(nfa.accepting & reached)>0;
    return !accepts;
}

@doc {
    A function to output a string that can beused to visualize the nfa using the following website:
    https://dreampuf.github.io/GraphvizOnline
}
str visualize(NFA[&T] nfa) {
    Maybe[str] def(TransSymbol _) = nothing();
    return visualize(nfa, def);
}
str visualize(NFA[&T] nfa, Maybe[str](TransSymbol sym) getLabel) {
    str name(&T nde) = "\""+replaceAll(replaceAll("<nde>", "\\", "\\\\"), "\"", "\\\"")+"\"";

    out = "digraph {\n";
    for(<from, on, to> <- nfa.transitions)  {
        str label = "";
        if(just(l) := getLabel(on)) label = l;
        else if(TransSymbol::character([range(1,0x10FFFF)]) := on) label = "*";
        else if(TransSymbol::character(charClass) := on) label = stringify(charClass);
        else if(regexp(r) := on) label = stringify(r);
        else if(epsilon() := on) label = "\\e";
        else label = "<on>";
        out += "    <name(from)> -\> <name(to)> [label=<name(label)>]\n";
    }
    out += "\n";
    out += "    <name(nfa.initial)> [shape=rect]\n";
    for(accepting <- nfa.accepting)
        out += "    <name(accepting)> [penwidth=4]\n";
    out += "}";

    return out;
}
// Used by conversion NFA
data TransSymbol = regexp(Regex r);