module regex::PSNFA

import String;
import Set;
import Scope;
import List;
import util::Maybe;

import regex::util::CreateOrdering;
import regex::NFA;
import regex::DFA;


// Groups are used for capture groups and to specify the main capture
data TransSymbol = border(set[Border] borders);
data LangSymbol = border(set[Border] borders);
alias Border = tuple[GroupType gt, BorderType bt];
data BorderType = begin() 
                | end();
data GroupType = match()
               | capture(set[value] tags);
data TextGroup = textGroup(GroupType gt, int begin, int length);

@doc{
    Checks whether the given prefix, text, and suffix is within the PSNFA's language
}
bool matches(NFA[&T] nfa, tuple[str, str, str] text) {
    return matches(
        nfa, 
        text<0> + text<1> + text<2>, 
        {textGroup(match(), size(text<0>), size(text<1>))});
}
bool matches(NFA[&T] nfa, str text, set[TextGroup] groups) {
    chars = getSymbolStream(text, groups);
    return matches(nfa, chars, psnfaMatch);
}
list[LangSymbol] getSymbolStream(str text, set[TextGroup] groups) {
    rel[int, Border] borders = {};
    for(textGroup(gt, beginI, length) <- groups) {
        endI = beginI + length;
        borders += <beginI, <gt, begin()>>;
        borders += <endI, <gt, end()>>;
    }

    list[tuple[int, TransSymbol]] borderSymbols = [];
    set[int] indices = sort(borders<0>);
    for(index <- indices)
        borderSymbols += <index, LangSymbol::border(indices[index])>;

    Maybe[tuple[int, TransSymbol]] next = none();
    if(size(borderSymbols) > 0) next = just(head(borderSymbols));

    list[LangSymbol] chars = [];
    for(index <- [0..size(text)]) {
        if(just(<bIndex, border>) := next && bIndex <= index){
            chars += other(border);
            if(size(borderSymbols) > 0) next = just(head(borderSymbols));
        }

        chars += char(charAt(text, index));
    }
    return chars;
}
MatchType psnfaMatch(LangSymbol input, TransSymbol match) {
    if(LangSymbol::border(langBorders) := input && TransSymbol::border(transBorders) := match) return langBorders == transBorders ? match() : none();
    return simpleMatch(input, match);
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
            if(trans == TransSymbol::border(borders) := trans) {
                if (any(<match(), end()> <- borders)) queue += <suffix(), to>; // Prefer matchEnd, in case both matchEnd and matchBegin are present
                else if(any(<match(), begin()> <- borders)) queue += <main(), to>;
                else queue += <sType, to>;
            } else queue += <sType, to>;
        }
    }

    return <prefixStates, mainStates, suffixStates>;
}
data StateType = prefix() | main() | suffix();

@doc {
    Joins all consecutive border transitions together to ensure there are no more consecutive border transitions, as required to be a valid PSNFA. Assumes no border loops to exist, nor any consecutive borders of the same exact type.
}
NFA[&T] mergeBorders(NFA[&T] n){
    set[&T] reached = {};
    set[&T] queue = {n.initial};

    while(size(queue)>0) {
        <state, queue> = takeOneFrom(queue);

        if(state in reached) continue;
        reached += state;

        queue += n.transitions[state]<1>;
    }
    mergeBorderStates(n, reached);
} 
@doc {
    Joins all consecutive border transitions together to ensure there are no more consecutive border transitions, as required to be a valid PSNFA. Assumes consecutive border transitions only to start from the given state set. Assumes no border loops to exist, nor any consecutive borders of the same exact type.
}
NFA[&T] mergeBorders(NFA[&T] n, set[&T] states) {
    rel[&T, TransSymbol, &T] transitions = n.transitions;

    list[&T] ordering = createOrdering(states, set[&T](&T state) {
        return {to | <border(_), to> <- transitions[state]};
    });

    rel[&T, TransSymbol, &T] allIncomingBorders;
    while(state <- ordering) {
        incomingBorders = allIncomingBorders[state];

        hasOutgoingBorder = false;
        for(<trans, to> <- transitions[state]) {
            if(exploreReachable || to in states) queue += {to};

            if(border(outgoingBorders) := trans) {
                hasOutgoingBorder = true;
                allIncomingBorders += <to, trans, state>;

                for(<border(incomingBorders), from> <- incomingBorders) {
                    combinedBorder = border({*incomingBorders, *outgoingBorders});

                    allIncomingBorders += <to, combinedBorder, from>;
                    transitions += <from, combinedBorder, to>;
                }                    
            }
        }

        for(<trans, from> <- incomingBorders){
            allIncomingBorders -= <from, trans, state>;
            if(hasOutgoingBorder)
                transitions -= <from, trans, state>;
        }            
    }

    return <n.initial, transitions, n.accepting>;
}