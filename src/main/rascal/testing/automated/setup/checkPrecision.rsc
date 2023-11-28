module testing::automated::setup::checkPrecision

import ParseTree;
import List;
import IO;
import String;
import Set;
import Grammar;

import Scope;

public alias Tokenization = list[list[Scope]];
@doc {
    Checks the precision of the given tokenizations,
    outputing the number of correct groups and the total number of groups, and a list of mistakes
}
data PrecisionData = precisionData(int correct, int total, list[TokenizationGroup] errors);
PrecisionData checkPrecision(str input, Tokenization spec, Tokenization tokenization) {

    groups = getTokenizationGroups(input, spec, tokenization);
    list[TokenizationGroup] errors = [group | group <- groups, group.spec != group.result];

    count = size(groups);
    return precisionData(count - size(errors), count, errors);
}

data TokenizationGroup = tokenizationGroup(str text, tuple[tuple[int, int], tuple[int, int]] range, list[Scope] spec, list[Scope] result);
list[TokenizationGroup] getTokenizationGroups(str input, Tokenization spec, Tokenization result) {
    tuple[int, int] pos = <1, 1>;
    if([specFirst, *_] := spec, [resultFirst, *_] := result) {
        list[TokenizationGroup] out = [];

        TokenizationGroup group = tokenizationGroup("", <pos, pos>, specFirst, resultFirst);
        for(i <- [0..size(input)], i < size(spec),  i < size(result)) {
            character = input[i];
            if(group.spec != spec[i] || group.result != result[i]) {
                out += group;
                group = tokenizationGroup("", <pos, pos>, spec[i], result[i]);
            } 

            pos[1] += 1;
            if(character=="\n") {
                pos[1] = 1;
                pos[0] += 1;
            }


            group.text += character;
            group.range[1] = pos;
        }

        return out + group;
    }
    return [];
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


list[Scope] getScopeCategories(prod(_, _, attributes)) = ["<token>" | \tag("category"(token)) <- attributes];
list[Scope] getScopeCategories(_) = [];

list[Scope] getTokenCategories(prod(s, _, attributes), tokens) 
    = ["<token>" | \tag("categoryTerm"(token)) <- attributes]
    when isTokenBorder(s);
list[Scope] getTokenCategories(regular(_), tokens) = [];
list[Scope] getTokenCategories(_, list[Scope] tokens) = tokens;

bool isTokenBorder(label(text, sym)) = isTokenBorder(sym);
bool isTokenBorder(sort(_)) = true;
bool isTokenBorder(lex(_)) = true;
bool isTokenBorder(\layouts(_)) = true;
bool isTokenBorder(\keywords(_)) = true;
bool isTokenBorder(_) = false;