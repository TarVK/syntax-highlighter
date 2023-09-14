module testing::conversionTest

import IO;
import ParseTree;

import testing::grammars::LambdaJSnew;
import testing::grammars::JS;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;

void main() {
    // grammar = toConversionGrammar(#Program);
    grammar = toConversionGrammar(#Source);

    loc pos = |project://syntax-highlighter/outputs/convGrammar.txt|;
    writeFile(pos, "<grammar>");
}