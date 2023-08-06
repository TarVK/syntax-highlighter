module testing::shapeTest

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
import conversion::shapeConversion::ShapeConversion;
import conversion::util::RegexCache;

syntax A = Stmt*;
syntax Stmt = cond: "if" "(" Exp ")"  Stmt
            | cond: "if" "(" Exp ")"  Stmt "else" Stmt
            | loop: "while" "(" Exp ")"  Stmt
            | block: "{" Stmt* "}"
            | exp: Exp;
syntax Exp = id: Id name
            | strcon: String string
            | natcon: Natural natcon
            | bracket "(" Exp e ")"
            > left concat: Exp lhs "||" Exp rhs
            > left ( add: Exp lhs "+" Exp rhs
                    | min: Exp lhs "-" Exp rhs
                    )
            ;

            
lexical Id  = [a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9] \ StatementKW;
lexical Natural = [0-9]+ !>> [0-9];
lexical String = "\"" ![\"]*  "\"";

keyword StatementKW = "if" | "while";

layout Layout = [\ \t\n\r]?;
// layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
// lexical WhitespaceAndComment 
//    = [\ \t\n\r]
//    | @category="Comment" "%" ![%]+ "%"
//    | @category="Comment" "%%" ![\n]* $
//    ;


void main() {
// // loc pos = |project://syntax-highlighter/outputs/deterministicGrammar.bin|;
    // loc inputPos = |project://syntax-highlighter/outputs/regexGrammar.bin|;
    // inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  inputPos);

    
    <cWarnings, conversionGrammar> = toConversionGrammar(#A);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar);
    inputGrammar = conversionGrammar;

    // <dWarnings, conversionGrammar> = makeDeterministic(conversionGrammar, 2);
    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar);


    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings + rWarnings + sWarnings;
    visualize(insertPSNFADiagrams(removeInnerRegexCache(stripConvSources(<
        fromConversionGrammar(inputGrammar),
        stdGrammar,
        warnings
    >))));
}