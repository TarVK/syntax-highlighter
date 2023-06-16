module testing::conversionTest

import IO;
import ParseTree;

import testing::grammars::LambdaJSnew;
import testing::grammars::JS;
import conversionGrammar::ConversionGrammar;

void main() {
    // grammar = toConversionGrammar(#Program);
    grammar = toConversionGrammar(#Source);

    loc pos = |project://syntax-highlighter/outputs/convGrammar.txt|;
    writeFile(pos, "<grammar>");
}