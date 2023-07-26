module testing::regexConversionTest

import IO;
import Grammar;
import ParseTree;
import ValueIO;

import Visualize;
import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::RegexConversion;
import conversionGrammar::RegexCache;
import regex::PSNFA;

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

// syntax A = "a" B "c" B
//          | "b" B "c" B
//          | B "c" B
//          | "a" B B
//          | "b" B B
//          | B B;


// syntax A = "a" B "c" B
//          | "a" B B;


// syntax A = [\ \t\n\r]
//    | "%"
//    | "%%" ![\n]* $
//    ;
// syntax A = "a"
//          | "b"
//          | "c"+;

// syntax A = idtype: ":" Type t;
// syntax Type 
//   = natural:"natural" 
//   | string :"string" 
//   | nil    :"nil-type"
//   ;

import testing::grammars::Pico;

// syntax A = @scope="smth" "a" B;
// syntax B = @token="stuff" "b";


void main() {
    loc pos = |project://syntax-highlighter/outputs/regexGrammar.bin|;
    <warnings, conversionGrammar> = toConversionGrammar(#A);
    conversionGrammar = convertToRegularExpressions(conversionGrammar);

    conversionGrammar = removeInnerRegexCache(stripConvSources(conversionGrammar));
    stdGrammar = fromConversionGrammar(conversionGrammar);

    visualize(insertPSNFADiagrams(<
        grammar(#A),
        stdGrammar
    >));

    writeBinaryValueFile(pos, conversionGrammar);
    if(size(warnings)>0) println(warnings);
}