
@synopsis{A precision measure}
@description{
    `getPrecisionPenalty` defines a measure that determines how well a tokenization corresponds to the one defined by a given grammar.
    A lower score score is better, since this measure describes a penalty. 

    TODO: describe how tokenization is infered from the grammar
}

module measures::Precision

import ParseTree;
import Type;
import String;

public alias Tokens = list[str];
public data CharacterTokens = characterTokens(int character, Tokens tokens);
public alias Tokenization = list[CharacterTokens];

// Tokenization of parse trees
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

// Token comparison
public data CharacterDifferences = characterDifferences(int character, int position, Tokens extra, Tokens missing);
public alias TokenizationDifferences = list[CharacterDifferences];


public TokenizationDifferences getTokenDifferences(Tokenization present, Tokenization expected) = getTokenDifferences(present, expected, 0);
public TokenizationDifferences getTokenDifferences([], [], int index) = [];
public TokenizationDifferences getTokenDifferences([presentChar, *presentRemainder], [expectedChar, *expectedRemainder], int index) 
    = getTokenDifferences(presentChar, expectedChar, index) + getTokenDifferences(presentRemainder, expectedRemainder, index + 1);
public TokenizationDifferences getTokenDifferences(characterTokens(char, present), characterTokens(_, expected), int index) {
    Tokens extra = [token | token <- present, !(token in expected)];
    Tokens missing = [token | token <- expected, !(token in present)];
    if (size(extra) == 0 && size(missing) == 0) return [];
    return [characterDifferences(char, index, extra, missing)];
}

public int getDifferenceCount(TokenizationDifferences differences) = (0 | it + size(extra) + size(missing) | characterDifferences(_, _, extra, missing) <- differences);
    

// The measure itself
public int getPrecisionPenalty(type[Tree] grammar, Tokenization tokens) {
    str text = ("" | it + stringChar(char) | characterTokens(char, _) <- tokens);
    Tokenization expectedTokens = getTokenization(grammar, text);

    TokenizationDifferences differences = getTokenDifferences(tokens, expectedTokens);
    int differenceCount = getDifferenceCount(differences);

    return differenceCount;
}
public int getPrecisionPenalty(type[Tree] spec, type[Tree] highlighter, str text) 
    = getPrecisionPenalty(spec, getTokenization(highlighter, text));