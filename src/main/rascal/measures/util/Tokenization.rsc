@synopsis{Tokenization tools}
@description{
    `getTokenization` can be used to retrieve a tokenization based on a parse tree or CFG and input string
}

module measures::util::Tokenization

import ParseTree;
import Type;

public alias Tokens = list[str];
public data CharacterTokens = characterTokens(int character, Tokens tokens);
public alias Tokenization = list[CharacterTokens];


public Tokenization getTokenization(type[Tree] grammar, str text)
     = getTokenization(parse(grammar, text, allowAmbiguity=true));
public Tokenization getTokenization(Tree tree) = getTokenization([], tree);
public Tokenization getTokenization(Tokens tokens, appl(prod, subtrees)) {
    childTokens = merge(tokens, getTokens(prod));
    return [*getTokenization(childTokens, subtree) | subtree <- subtrees];
}
public Tokenization getTokenization(Tokens tokens, amb({tree, *rest})) = getTokenization(tokens, tree);
public Tokenization getTokenization(Tokens tokens, char(character)) = [characterTokens(character, tokens)];

public Tokens getTokens(prod(_, _, attributes)) = ["<token>" | \tag("category"(token)) <- attributes];
public Tokens getTokens(_) = [];

public Tokens merge(Tokens tokens, []) = tokens;
public Tokens merge(Tokens tokens, [first, *rest]) = merge(first in tokens ? tokens : tokens + first, rest);
