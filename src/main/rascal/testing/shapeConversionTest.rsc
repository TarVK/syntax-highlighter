module testing::shapeConversionTest

import ValueIO;

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

import conversion::util::equality::getEquivalentSymbols;
import Warning;

import testing::grammars::SimpleScoped1;

// start syntax Program = Stmt*;
// syntax Stmt = 
//             // exp: Exp
//             assign: Id "=" Exp ";"
//             // | iff: "if" >> ("("|[\n\ ]) "(" Exp ")" Stmt
//             // | iff: "if" >> ("("|[\n\ ]) "(" Exp ")" Stmt "else" !>> [a-z0-9] Stmt
//             // | iff: "if" >> ("("|[\n\ ]) Stmt
//             // | iff: "if" >> ("("|[\n\ ]) Stmt "else"!>>[a-z0-9] Stmt
//             // | @token="KW" "in" !>> [a-z0-9]
//             | forIn: "for" >> ("("|[\n\ ]) "(" Id "in" !>> [a-z0-9] Exp ")" Stmt
//             // | forIter: "for" >> ("("|[\n\ ]) "(" Exp ";" Exp ";" Exp ")" Stmt
//             // | forIn: "for" >> ("("|[\n\ ]) "(" Exp "in" !>> [a-z0-9] Id ")" Stmt
//             | forIter: "for" >> ("("|[\n\ ]) "(" Exp ";" Exp ";" Exp ")" Stmt
//             // | forIn: "(" "in" !>> [a-z0-9] Exp ")" Stmt
//             // | forIn: "(" Exp ")" Stmt
//             ;
// syntax Exp = id: Id
//            | brackets: "(" Exp ")"
//            | Exp "in" Exp 
//            ;

// lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
// keyword KW = "for"|"in"|"if"|"true"|"false"|"else";

// layout Layout = [\n\ ]* !>> [\n\ ];



void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = false;

    log = standardLogger();
    list[Warning] cWarnings, rWarnings, pWarnings, sWarnings;
    ConversionGrammar inputGrammar, conversionGrammar;
    if(recalc) {
        <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        inputGrammar = conversionGrammar;
        <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, log);
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
        cWarnings = rWarnings = pWarnings = [];
    }

    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, log);

    // Simplify for readability
    conversionGrammar = replaceNfaByRegex(conversionGrammar);
    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    <conversionGrammar, symMap> = relabelGeneratedSymbolsWithMapping(conversionGrammar);

    warnings = cWarnings + rWarnings + pWarnings + sWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings,
        conversionGrammar.\start
        , symMap
    >);
}