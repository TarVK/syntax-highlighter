module testing::regexConversionTest

import IO;
import Grammar;
import ParseTree;
import ValueIO;

import Visualize;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::RegexConversion;
import conversion::util::RegexCache;
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



// syntax A = {EXP ","}+;
// syntax EXP = Name
//            | EXP "+" EXP;
// lexical Name = [a-zA-Z]+ !>> [a-zA-Z];

// layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];

// lexical WhitespaceAndComment 
//    = [\ \t\n\r]
//    | @category="Comment" "%" ![%]+ "%"
//    | @category="Comment" "%%" ![\n]* $
//    ;

// import testing::grammars::Pico;
import testing::grammars::PicoImproved;


void main() {
    loc pos = |project://syntax-highlighter/outputs/regexGrammar.bin|;
    <lWarnings, conversionGrammar> = toConversionGrammar(#A);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar);

    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = lWarnings + rWarnings;
    visualize(insertPSNFADiagrams(removeInnerRegexCache(stripConvSources(<
        grammar(#A),
        stdGrammar, 
        warnings
    >))));

    writeBinaryValueFile(pos, conversionGrammar);
}