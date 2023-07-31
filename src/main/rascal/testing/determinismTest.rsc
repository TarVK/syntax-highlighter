module testing::determinismTest

import IO;
import Grammar;
import ParseTree;
import ValueIO;

import Visualize;
import regex::PSNFA;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::RegexConversion;
import conversion::determinism::Determinism;

// syntax A = "okay" B
//          | "somethings" C;

// syntax B = "s"*;
// syntax C = "s"* !>> "s";

// syntax A = "something"
//          | "someth";

// syntax A = "if" Exp "fi"
//          | Id ":=" Exp;
// syntax Exp = Id
//            | String
//            | Natural
//            | "(" Exp ")"
//            > left concat: Exp lhs "||" Exp rhs
//            > left ( add: Exp lhs "+" Exp rhs
//                     | min: Exp lhs "-" Exp rhs
//                     );

           
// lexical Id  = [a-z][a-z0-9]* !>> [a-z0-9];
// lexical Natural = [0-9]+ !>> [a-z0-9];
// lexical String = "\"" ![\"]*  "\"";

           

// layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
// lexical WhitespaceAndComment 
//    = [\ \t\n\r]
//    | @category="Comment" "%" ![%]+ "%"
//    | @category="Comment" "%%" ![\n]* $
//    ;

// import testing::grammars::Pico;
import testing::grammars::PicoImproved;

void main() {
    // // loc pos = |project://syntax-highlighter/outputs/deterministicGrammar.bin|;
    // loc inputPos = |project://syntax-highlighter/outputs/regexGrammar.bin|;
    // inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  inputPos);

    
    <warnings, conversionGrammar> = toConversionGrammar(#A);
    inputGrammar = conversionGrammar = convertToRegularExpressions(conversionGrammar);

    <dWarnings, conversionGrammar> = makeDeterministic(conversionGrammar, 2);

    conversionGrammar = stripConvSources(conversionGrammar);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    visualize(insertPSNFADiagrams(<
        fromConversionGrammar(inputGrammar),
        stdGrammar,
        dWarnings
    >));
}