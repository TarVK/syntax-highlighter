module regex::NFATypes

import ParseTree;

alias NFA[&T] = tuple[&T initial, rel[&T, TransSymbol, &T] transitions, set[&T] accepting, value meta];

data TransSymbol = character(CharClass char)
                 | epsilon();
data LangSymbol = characterL(int code);

alias CharMatcher = bool(LangSymbol input, TransSymbol transition);