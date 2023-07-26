module regex::NFA
extend regex::NFATypes;

import String;
import util::Maybe;
import ParseTree;
import Set;

import regex::NFATypes;
import regex::util::charClass;
import regex::util::expandEpsilon;
import Visualize;

set[&T] getStates(NFA[&T] n) = n.transitions<0> + n.transitions<2> + {n.initial} + n.accepting;

@doc{
    Checks whether the given text is within the NFA's language
}
bool matches(NFA[&T] n, str text) {
    list[LangSymbol] chars = [];
    for(index <- [0..size(text)])
        chars += characterL(charAt(text, index));
    return matches(n, chars, simpleMatch);
}
bool simpleMatch(LangSymbol input, TransSymbol match) {
    if(epsilon() == match) return false;
    else if(character(ranges) := match) return characterL(charCode) := input && contains(ranges, charCode);
    return false;
}
bool matches(NFA[&T] n, list[LangSymbol] input, CharMatcher matcher) {
    states = expandEpsilon(n, {n.initial});

    for (symbol <- input) {
        newStates = {};
        for(state <- states) {
            transitions = n.transitions[state];
            for(<match, to> <- transitions) {
                matches = matcher(symbol, match);

                if (!matches) continue;
                newStates += to;
            }
        }
        states = expandEpsilon(n, newStates);
    }

    accepts = size(n.accepting & states)>0;
    return accepts;
}
bool contains(CharClass ranges, int char) {
    for(range(from, to) <- ranges)
        if(from <= char && char <= to) return true;
    return false;
}


@doc{
    Checks whether the given NFA's language is empty
}
bool isEmpty(NFA[&T] n) {
    added = {n.initial};
    reached = added;
    while(size(added)>0) {
        newAdded = {};
        for(state <- added) {
            transitions = n.transitions[state];
            for(<_, to> <- transitions){
                if(to in reached) continue;
                newAdded += to;
                reached += to;
            }
        }
        added = newAdded;
    }
    
    accepts = size(n.accepting & reached)>0;
    return !accepts;
}


@doc {
    Obtains an isomorphic NFA with each state remapped
}
NFA[&K] mapStates(NFA[&T] n, &K(&T) mapState) {
    states = getStates(n);

    map[&T, &K] stateMapping = ();
    for(state <- states)
        stateMapping[state] = mapState(state);

    return <
        stateMapping[n.initial],
        {<stateMapping[from], sym, stateMapping[to]> | <from, sym, to> <- n.transitions},
        {stateMapping[state] | state <- n.accepting},
        ()
    >;
}

@doc {
    A function to output a string that can beused to visualize the nfa using the following website:
    https://dreampuf.github.io/GraphvizOnline
}
str visualizeText(NFA[&T] n) {
    Maybe[str] def(TransSymbol _) = nothing();
    return visualizeText(n, def);
}
str visualizeText(NFA[&T] n, Maybe[str](TransSymbol sym) getLabel) {
    str name(&T nde) = "\""+replaceAll(replaceAll("<nde>", "\\", "\\\\"), "\"", "\\\"")+"\"";

    out = "digraph {\n";
    for(<from, on, to> <- n.transitions)  {
        str label = "";
        if(just(l) := getLabel(on)) label = l;
        else if(TransSymbol::character([range(1,0x10FFFF)]) := on) label = "*";
        else if(TransSymbol::character(charClass) := on) label = stringify(charClass);
        else if(epsilon() := on) label = "\\e";
        else label = "<on>";
        out += "    <name(from)> -\> <name(to)> [label=<name(label)>]\n";
    }
    out += "\n";
    out += "    <name(n.initial)> [shape=rect]\n";
    for(accepting <- n.accepting)
        out += "    <name(accepting)> [penwidth=4]\n";
    out += "}";

    return out;
}

@doc {
    Converts a NFA to a diagram that can be shown using Rascal-vis (https://github.com/TarVK/rascal-vis)
}
RascalVisGraph toDiagram(NFA[&T] n) = toDiagram(n, Maybe[str](TransSymbol _){ return nothing(); });
RascalVisGraph toDiagram(NFA[&T] n, Maybe[str](TransSymbol sym) getLabel) {
    set[RascalVisGraphNode] nodes = {VNode(state, name="<state>") | state <- getStates(n)};

    set[RascalVisGraphEdge] edges = {};
    for(<from, on, to> <- n.transitions)  {
        str label = "";
        if(just(l) := getLabel(on)) label = l;
        else if(TransSymbol::character([range(1,0x10FFFF)]) := on) label = "*";
        else if(TransSymbol::character(charClass) := on) label = stringify(charClass);
        else if(epsilon() := on) label = "$e";
        else label = "<on>";
        edges += VEdge(from, to, name=label);
    }

    return VGraph(nodes, edges);
}