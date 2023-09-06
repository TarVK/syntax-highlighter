module testing::baseConversionTest


import IO;
import Grammar;
import ParseTree;
import ValueIO;

import Visualize;
import regex::PSNFA;
import conversion::util::RegexCache;
import conversion::util::Simplification;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::RegexConversion;
import conversion::determinism::Determinism;
import conversion::baseConversion::BaseConversion;
import conversion::shapeConversion::ShapeConversion;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::makePrefixedRightRecursive;



syntax A = Stmt*;
syntax Stmt = forIn: "for" "(" Id "in" !>> [a-z0-9] Exp ")" Stmt
            | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt
            | iff: "if" "(" Exp ")" Stmt
            | iffElse: "if" "(" Exp ")" Stmt "else" Stmt
            | "{" Stmt* "}"
            | assign: Id "=" Exp;
syntax Exp = brac: "(" Exp ")"
           | plus: Exp "+" Exp
           | inn: Exp "in" !>> [a-z0-9] Exp
           | id: Id
           | nat: Natural;
layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];
keyword KW = "for"|"in"|"if";
lexical Id  = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical Natural = [0-9]+ !>> [a-z0-9];



void main() {    
    <cWarnings, conversionGrammar> = toConversionGrammar(#A);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar);
    inputGrammar = conversionGrammar;
    
    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar);
    <dWarnings, conversionGrammar> = makeDeterministic(conversionGrammar);
    <bWarnings, conversionGrammar> = makeBaseProductions(conversionGrammar);
    // bWarnings = [];

    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    conversionGrammar = relabelGenerated(conversionGrammar);

    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings + rWarnings + sWarnings + dWarnings + bWarnings;
    visualize(insertPSNFADiagrams(removeInnerRegexCache(stripConvSources(<
        fromConversionGrammar(inputGrammar),
        stdGrammar,
        warnings
    >))));
}