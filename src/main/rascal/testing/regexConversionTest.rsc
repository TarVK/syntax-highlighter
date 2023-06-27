module testing::regexConversionTest

import IO;
import ParseTree;

import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::RegexConversion;

syntax A = @token="b" B "a" B "c"
         | @token="b" B "c" B "c"
         | @token="b" B "d" B "c"
         | @token="b" B "a" B "d"
         | @token="b" B "c" B "d"
         | @token="b" B "d" B "d"
         | "a" B "c"
         | "b" B "c"
         | "c"
         | "d";

// syntax A = B "a" B "c"
//          | B "c" B "c"
//          | B "a" B "d"
//          | B "c" B "d";
syntax B = "b";

void main() {
    if(<warnings, grammar> := toConversionGrammar(#A)){
        grammar = convertToRegularExpressions(grammar);

        loc pos = |project://syntax-highlighter/outputs/regexGrammar.txt|;
        writeFile(pos, "<grammar>");
    }
}