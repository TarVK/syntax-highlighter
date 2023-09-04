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
import conversion::shapeConversion::ShapeConversion;
import conversion::util::RegexCache;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::makePrefixedRightRecursive;

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


// syntax A = Stmt*;
// syntax Stmt = iff: "if" "(" Exp ")" Stmt
//             | iff: If "(" Exp ")" Stmt
//             | assign: Id "=" Exp;
// syntax If = @token="if" "if";
// syntax Exp = brac: "(" Exp ")"
//            | plus: Exp "+" Exp
//            | id: Id
//            | nat: Natural;
// layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
// lexical Id  = [a-z] !<< ([a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
// lexical KW = "if" | "else";
// lexical Natural = [0-9]+ !>> [a-z0-9];

syntax A = Stmt*;
syntax Stmt = ifElse: "if" "(" Exp ")" Stmt "else" !>> [a-z0-9] Stmt
            | iff: "if" "(" Exp ")" Stmt
            | assign: Id "=" Exp;
syntax Exp = brac: "(" Exp ")"
           | plus: Exp "+" Exp
           | id: Id
           | nat: Natural;
layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
lexical Id  = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical KW = "if" | "else";
lexical Natural = [0-9]+ !>> [a-z0-9];


// syntax A = Stmt;
// syntax Stmt = ifElse: "if" "(" Exp ")" Stmt "else" Stmt
//             | iff: "if" "(" Exp ")" Stmt
//             | assign: Id "=" Exp;
// syntax Exp = plus: Exp "+" Exp
//            | nat: Natural;
// layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
// lexical Id  = [a-z][a-z0-9]* !>> [a-z0-9];
// lexical Natural = [0-9]+ !>> [a-z0-9];


// syntax A = Stmt*;
// syntax Stmt = forIn: "for" "(" Id "in" Exp ")" Stmt "else" Stmt
//             | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt
//             | assign: Id "=" Exp;
// syntax Exp = brac: "(" Exp ")"
//            | plus: Exp "+" Exp
//            | id: Id \ KW
//            | nat: Natural;
// layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
// keyword KW = "for";
// lexical Id  = [a-z][a-z0-9]* !>> [a-z0-9];
// lexical Natural = [0-9]+ !>> [a-z0-9];


// syntax A = Stmt*;
// syntax Stmt = forIn: "for" "(" Exp "in" Exp ")" Stmt
//             | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt
//             | assign: Id "=" Exp;
// syntax Exp = brac: "(" Exp ")"
//            | plus: Exp "+" Exp
//            | id: Id
//            | nat: Natural;
// layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
// lexical Id  = [a-z][a-z0-9]* !>> [a-z0-9];
// lexical Natural = [0-9]+ !>> [a-z0-9];


// syntax A = Stmt*;
// syntax Stmt = forIn: "for" "(" Exp "in" Exp ")" Stmt
//             | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt
//             | assign: Id "=" Exp;
// syntax Exp = id: Id
//            | "(" Exp ")";
// layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
// lexical Id  = ([a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
// keyword KW = "for";

// syntax A = Stmt;
// syntax Stmt = forIn: "for" "(" Exp "in" Exp ")" Stmt
//             | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt;
//             // | assign: Id "=" Exp;
// syntax Exp = id: Id;
// layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
// lexical Id  = [a-z][a-z0-9]* !>> [a-z0-9];

// syntax A = "b"? >> "(" B "c"? >> ("("|"[") C "d" D
//          | "e"? E "d" D
//          | "k";
// syntax B = "(|"? A "|)"
//          | "(" B ")";
// syntax C = "(|"? A "|)"
//          | "[" C "]";
// syntax D = "{" D "}"
//          | ;
// syntax E = "\<" E "\>"
//          | ;

// syntax A = "b"? >> "(" B "c" >> ("("|"[") C "d" D
//          | "e" E "d" D
//          | "k";
// syntax B = "(|"? A "|)"
//          | "(" B ")";
// syntax C = "(|" A "|)"
//          | "[" C "]";
// syntax D = "{" D "}"
//          | ;
// syntax E = "\<" E "\>"
//          | ;

// import testing::grammars::Pico;
// import testing::grammars::PicoImproved;

void main() {
    // // loc pos = |project://syntax-highlighter/outputs/deterministicGrammar.bin|;
    // loc inputPos = |project://syntax-highlighter/outputs/regexGrammar.bin|;
    // inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  inputPos);

    
    <cWarnings, conversionGrammar> = toConversionGrammar(#A);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar);
    // <_, inputGrammar> = makePrefixedRightRecursive(conversionGrammar);
    
    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar);
    // subsets = getSubsetSymbols(conversionGrammar);

    inputGrammar = conversionGrammar;
    <dWarnings, conversionGrammar> = makeDeterministic(conversionGrammar);

    classes = getEquivalentSymbols(conversionGrammar);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings + rWarnings + sWarnings + dWarnings;
    visualize(insertPSNFADiagrams(removeInnerRegexCache(stripConvSources(<
        fromConversionGrammar(inputGrammar),
        stdGrammar,
        warnings,
        classes
        // subsets
    >))));
}