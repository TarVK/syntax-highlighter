module testing::manual::determinismTest

import ValueIO;
import lang::json::IO;

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;
import conversion::prefixConversion::convertToPrefixed;
import conversion::shapeConversion::convertToShape;
import conversion::util::transforms::relabelSymbols;
import conversion::util::transforms::removeUnreachable;
import conversion::util::transforms::removeAliases;
import conversion::util::transforms::replaceNfaByRegex;
import determinism::check::checkDeterminism;


import conversion::util::equality::getEquivalentSymbols;
import Warning;
import TestConfig;

// import testing::grammars::SimpleScoped1;

syntax Program = Stmt*;
syntax Stmt = exp: Exp
            // | @categoryTerm="keyword" iff: "if" >> ("("|[\n\ ]) "(" Exp ")" Stmt
            | @categoryTerm="keyword" iff: "if" >> ("("|[\n\ ]) "(" Exp ")" Stmt "else" Stmt
            // | iff: "if" >> ("("|[\n\ ]) Stmt
            // | iff: "if" >> ("("|[\n\ ]) Stmt "else" Stmt
            // | @categoryTerm="KW" "in" !>> [a-z0-9]
            | forIn: "for" >> ("("|[\n\ ]) "(" Id "in" !>> [a-z0-9] Exp ")" Stmt
            | forIter: "for" >> ("("|[\n\ ]) "(" Exp ";" Exp ";" Exp ")" Stmt
            // | forIn: "for" >> ("("|[\n\ ]) "(" Exp "in" !>> [a-z0-9] Id ")" Stmt
            // | forIter: "for" >> ("("|[\n\ ]) "(" Exp ";" Exp ";" Exp ")" Stmt
            // | forIn: "(" "in" !>> [a-z0-9] Exp ")" Stmt
            // | forIn: "(" Exp ")" Stmt
            ;
syntax Exp = id: Id
           | brackets: "(" Exp ")"
           | close: ")"
           | @categoryTerm="keyword.operator" Exp "in" !>>[a-z0-9] Exp 
           ;

lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
keyword KW = "for"|"in"|"if"|"true"|"false"|"else";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="comment.block" "%" !>> "%" ![%]+ "%"
   | @category="comment.line" "%%" ![\n]* $
   ;

void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = false;

    log = standardLogger();
    list[Warning] cWarnings = [], 
                  rWarnings = [], 
                  pWarnings = [], 
                  sWarnings = [], 
                  mWarnings = [],
                  dWarnings = [];
    ConversionGrammar inputGrammar, conversionGrammar;
    if(recalc) {
        <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
        inputGrammar = conversionGrammar;
        c = testConfig(log = log);
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, c);
        <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, c);
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
        inputGrammar = conversionGrammar;
        conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
    }

    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    conversionGrammar = relabelGeneratedSymbols(conversionGrammar);
    dWarnings = checkDeterminism(conversionGrammar, log);
    log(Section(), "finished");

    warnings = cWarnings + rWarnings + pWarnings + sWarnings + mWarnings + dWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings,
        conversionGrammar.\start
    >);
}