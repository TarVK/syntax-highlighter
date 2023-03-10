
@synopsis{A precision measure}
@description{
    `getPrecisionPenalty` defines a measure that determines how well a tokenization corresponds to the one defined by a given grammar.
    A lower score score is better, since this measure describes a penalty. 

    The penalty is the sum token differences per character. Where the token differences for one character are described as the sum of additional and missing tokens. 
}

module measures::Precision

import ParseTree;
import String;
import measures::util::Tokenization;
import measures::util::TokenComparison;

int getPrecisionPenalty(type[Tree] grammar, Tokenization tokens) {
    str text = ("" | it + stringChar(char) | characterTokens(char, _) <- tokens);
    Tokenization expectedTokens = getTokenization(grammar, text);

    TokenizationDifferences differences = getTokenDifferences(tokens, expectedTokens);
    int differenceCount = getDifferenceCount(differences);

    return differenceCount;
}
int getPrecisionPenalty(type[Tree] spec, type[Tree] highlighter, str text) 
    = getPrecisionPenalty(spec, getTokenization(highlighter, text));