module regex::PSNFATypes

import ParseTree;

import regex::Tags;

data TransSymbol = matchStart()
                 | matchEnd()
                 | character(CharClass char, TagsClass tags);
data LangSymbol = matchStartL()
                | matchEndL()
                | characterL(int code, Tags tags);
                
data State = simple(str name)
           | stateLabel(str name, State state)
           | statePair(State a, State b)
           | stateSet(set[State] states);