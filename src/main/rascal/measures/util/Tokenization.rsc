@synopsis{Tokenization tools}
@description{
    `getTokenization` can be used to retrieve a tokenization based on a parse tree or CFG and input string
}

module measures::util::Tokenization

import ParseTree;
import Type;

alias Tokens = list[str];
data CharacterTokens = characterTokens(int character, Tokens tokens);
alias Tokenization = list[CharacterTokens];


Tokenization getTokenization(type[Tree] grammar, str text)
     = getTokenization(parse(grammar, text, allowAmbiguity=true));
Tokenization getTokenization(Tree tree) = getTokenization([], tree);
Tokenization getTokenization(Tokens tokens, appl(prod, subtrees)) {
    childTokens = merge(tokens, getTokens(prod));
    return [*getTokenization(childTokens, subtree) | subtree <- subtrees];
}
Tokenization getTokenization(Tokens tokens, amb({tree, *rest})) = getTokenization(tokens, tree);
Tokenization getTokenization(Tokens tokens, char(character)) = [characterTokens(character, tokens)];

Tokens getTokens(prod(_, _, attributes)) = ["<token>" | \tag("category"(token)) <- attributes];
Tokens getTokens(_) = [];

Tokens merge(Tokens tokens, []) = tokens;
Tokens merge(Tokens tokens, [first, *rest]) = merge(first in tokens ? tokens : tokens + first, rest);
