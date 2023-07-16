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
         | @token="b" B "a" B "o"
         | @token="b" B "ce" B "o"
         | @token="b" B "d" B "o"
         | "a" B >> D "c"
         | "b" B >> D "c"
         | "c"
         | "d";

// syntax A = B "a" B "c"
//          | B "c" B "c"
//          | B "a" B "d"
//          | B "c" B "d";
syntax B = "b"
         | "ab"
         | @scope="c" C;

syntax C = "c"
         | "ac";
syntax D = [a-z];

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