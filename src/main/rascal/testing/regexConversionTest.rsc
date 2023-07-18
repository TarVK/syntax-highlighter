module testing::regexConversionTest

import IO;
import Grammar;
import ParseTree;

import Visualize;
import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::RegexConversion;

// syntax A = @token="b" B "a" B "i"
//          | @token="b" B "ce" B "i"
//          | @token="b" B "d" B "i"
//          | @token="b" B "a" C+ "o"
//          | @token="b" B "ce" C+ "o"
//          | @token="b" B "d" C+ "o"
//          | "a" B >> D "c"
//          | "b" B >> D "c"
//          | "c"
//          | "d";
// syntax B = "b"
//          | "ab"
//          | @scope="C" C;
// syntax C = @token="c" "c"
//          | @token="c" "ac";
// syntax D = E
//          | E D
//          | @token="rd" D "D";
// syntax E = @scope="rd" F;
// syntax F = [a-z];

// syntax A = @scope="B" B;
// syntax B = @token="d,b" "b";

syntax A = "a" B "c" B
         | "b" B "c" B
         | B "c" B
         | "a" B B
         | "b" B B
         | B B;
// syntax A = "a" B "c" B
//          | "a" B B;

void main() {
    if(<warnings, conversionGrammar> := toConversionGrammar(#A)){
        conversionGrammar = convertToRegularExpressions(conversionGrammar);
        conversionGrammar = stripConvSources(conversionGrammar);
        stdGrammar = fromConversionGrammar(conversionGrammar);

        visualize(<
            grammar(#A),
            stdGrammar
        >);

        if(size(warnings)>0) println(warnings);

        // loc pos = |project://syntax-highlighter/outputs/regexGrammar.txt|;
        // writeFile(pos, "<stdGrammar>");
    }
}