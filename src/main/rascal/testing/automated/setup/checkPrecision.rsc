module testing::automated::setup::checkPrecision

import ParseTree;
import List;
import IO;
import Set;
import Grammar;

import Scope;

public alias Tokenization = list[list[Scope]];
@doc {
    Checks the precision of the given tokenizations,
    outputing the number of correct characters, and a list of mistakes
}
tuple[int, list[tuple[str, tuple[int, int], ScopeList, ScopeList]]] checkPrecision(str input, Tokenization spec, Tokenization tokenization) {

    list[tuple[str, tuple[int, int], ScopeList, ScopeList]] errors = [];
    int correct = 0;
    int line = 1;
    int column = 1;

    for(i <- [0..size(tokenization)]) {
        character = input[i];
        specScope = spec[i];
        tokenizationScope = tokenization[i];
        if(specScope==tokenizationScope) correct += 1;
        else errors += [<character, <line,column>, specScope, tokenizationScope>];

        column += 1;
        if(character=="\n") {
            column = 1;
            line += 1;
        }
    }

    return <correct, errors>;
}

Tokenization getTokenization(type[Tree] g, str input)
    = getTokenization(grammar(g), input);
Tokenization getTokenization(Grammar grammar, str input) {
    value treeType = type(getOneFrom(grammar.starts), grammar.rules); 
    tree = parse(treeType, input, allowAmbiguity=true);
    return getTokenization([], [], tree);
}
Tokenization getTokenization(list[Scope] scope, list[Scope] tokens, appl(prod, subtrees)) {
    scope += getScopeCategories(prod);
    tokens = getTokenCategories(prod, tokens);
    return [*getTokenization(scope, tokens, subtree) | subtree <- subtrees];
}
Tokenization getTokenization(list[Scope] scope, list[Scope] tokens, amb({tree, *rest})) = getTokenization(scope, tokens, tree);
Tokenization getTokenization(list[Scope] scope, list[Scope] tokens, char(character)) = [scope + tokens];


list[Scope] getScopeCategories(prod(_, _, attributes)) = ["<token>" | \tag("scope"(token)) <- attributes];
list[Scope] getScopeCategories(_) = [];

list[Scope] getTokenCategories(prod(s, _, attributes), tokens) 
    = ["<token>" | \tag("token"(token)) <- attributes]
    when isTokenBorder(s);
list[Scope] getTokenCategories(regular(_), tokens) = [];
list[Scope] getTokenCategories(_, list[Scope] tokens) = tokens;

bool isTokenBorder(label(text, sym)) = isTokenBorder(sym);
bool isTokenBorder(sort(_)) = true;
bool isTokenBorder(lex(_)) = true;
bool isTokenBorder(\layouts(_)) = true;
bool isTokenBorder(\keywords(_)) = true;
bool isTokenBorder(_) = false;