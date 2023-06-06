module regex::NFA

import String;
import util::Maybe;
import ParseTree;
import Set;
import lang::rascal::format::Grammar;

alias NFA[&T] = tuple[&T initial, rel[&T, TransSymbol, &T] transitions, set[&T] accepting];

data TransSymbol = character(CharClass char)
                 | epsilon();
data LangSym = char(int code)
             | literal(TransSymbol symb);

@doc{
    Checks whether the given text is within the NFA's language
}
bool matches(NFA[&T] nfa, str text) {
    list[LangSym] chars = [];
    for(index <- [0..size(text)])
        chars += char(charAt(text, index));
    return matches(nfa, chars);
}
bool matches(NFA[&T] nfa, list[LangSym] input) {
    states = expandEpsilon(nfa, {nfa.initial});

    for (symbol <- input) {
        newStates = {};
        for(state <- states) {
            transitions = nfa.transitions[state];
            for(<match, to> <- transitions) {
                matches = false;
                if(epsilon() == match) matches = false;
                else if(character(ranges) := match) matches = char(charCode) := symbol && contains(ranges, charCode);
                else matches = literal(sym) := symbol && sym := match;

                if (!matches) continue;
                newStates += to;
            }
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
                newAdded += to;
                states += to;
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
    Relabels all states of the given NFA to a numeric one
}
NFA[int] relabel(NFA[&T] nfa) {
    states = nfa.transitions<0> + nfa.transitions<2>;

    maxID = 0;
    map[&T, int] stateMapping = ();
    for(state <- states) {
        stateMapping[state] = maxID;
        maxID += 1;
    }

    return <
        stateMapping[nfa.initial],
        {<stateMapping[from], sym, stateMapping[to]> | <from, sym, to> <- nfa.transitions},
        {stateMapping[state] | state <- nfa.accepting}
    >;
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
        else if(character([range(1,0x10FFFF)]) := on) label = "*";
        else if(character(charClass) := on) label = cc2rascal(charClass);
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
