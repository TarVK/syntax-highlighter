module testing::regexConversionTest

import IO;
import Grammar;
import ParseTree;

import Visualize;
import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::RegexConversion;

syntax A = @token="b" B "a" B "i"
         | @token="b" B "ce" B "i"
         | @token="b" B "d" B "i"
         | @token="b" B "a" C+ "o"
         | @token="b" B "ce" C+ "o"
         | @token="b" B "d" C+ "o"
         | "a" B >> D "c"
         | "b" B >> D "c"
         | "c"
         | "d";
syntax B = "b"
         | "ab"
         | @scope="C" C;
syntax C = @token="c" "c"
         | @token="c" "ac";
syntax D = [a-z];

// syntax A = B+;
// syntax B = "B";

void main() {
    if(<warnings, conversionGrammar> := toConversionGrammar(#A)){
        conversionGrammar = convertToRegularExpressions(conversionGrammar);
        conversionGrammar = stripConvSources(conversionGrammar);
        stdGrammar = fromConversionGrammar(conversionGrammar);

        visualize(<
            grammar(#A),
            stdGrammar
        >);

        // loc pos = |project://syntax-highlighter/outputs/regexGrammar.txt|;
        // writeFile(pos, "<stdGrammar>");
    }
}