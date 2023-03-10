@synopsis{Token comparison}
@description{
    Utilities for comparing multiple tokenizations
}

module measures::util::TokenComparison

import ParseTree;
import Type;
import String;
import measures::util::Tokenization;


data CharacterDifferences = characterDifferences(int character, int position, Tokens extra, Tokens missing);
alias TokenizationDifferences = list[CharacterDifferences];

TokenizationDifferences getTokenDifferences(Tokenization present, Tokenization expected) = getTokenDifferences(present, expected, 0);
TokenizationDifferences getTokenDifferences([], [], int index) = [];
TokenizationDifferences getTokenDifferences([presentChar, *presentRemainder], [expectedChar, *expectedRemainder], int index) 
    = getTokenDifferences(presentChar, expectedChar, index) + getTokenDifferences(presentRemainder, expectedRemainder, index + 1);
TokenizationDifferences getTokenDifferences(characterTokens(char, present), characterTokens(_, expected), int index) {
    Tokens extra = [token | token <- present, !(token in expected)];
    Tokens missing = [token | token <- expected, !(token in present)];
    if (size(extra) == 0 && size(missing) == 0) return [];
    return [characterDifferences(char, index, extra, missing)];
}

int getDifferenceCount(TokenizationDifferences differences) = (0 | it + size(extra) + size(missing) | characterDifferences(_, _, extra, missing) <- differences);
    
