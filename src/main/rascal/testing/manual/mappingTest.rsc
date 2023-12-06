module testing::manual::mappingTest

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

import regex::Regex;
import mapping::intermediate::scopeGrammar::toScopeGrammar;
import mapping::textmate::createTextmateGrammar;
import mapping::common::HighlightGrammarData;

import conversion::util::equality::getEquivalentSymbols;
import Warning;
import TestConfig;

import testing::grammars::SimpleScoped1;

// syntax Program = Stmt*;
// syntax Stmt = exp: Exp
//             // | @categoryTerm="keyword" iff: "if" >> ("("|[\n\ ]) "(" Exp ")" Stmt
//             // | @categoryTerm="keyword" iff: "if" >> ("("|[\n\ ]) "(" Exp ")" Stmt "else" Stmt
//             // | iff: "if" >> ("("|[\n\ ]) Stmt
//             // | iff: "if" >> ("("|[\n\ ]) Stmt "else"!>>[a-z0-9] Stmt
//             // | @categoryTerm="KW" "in" !>> [a-z0-9]
//             // | forIn: "for" >> ("("|[\n\ ]) "(" Id "in" !>> [a-z0-9] Exp ")" Stmt
//             // | forIter: "for" >> ("("|[\n\ ]) "(" Exp ";" Exp ";" Exp ")" Stmt
//             // | forIn: "for" >> ("("|[\n\ ]) "(" Exp "in" !>> [a-z0-9] Id ")" Stmt
//             // | forIter: "for" >> ("("|[\n\ ]) "(" Exp ";" Exp ";" Exp ")" Stmt
//             // | forIn: "(" "in" !>> [a-z0-9] Exp ")" Stmt
//             // | forIn: "(" Exp ")" Stmt
//             ;
// syntax Exp = id: Id
//            | brackets: "(" Exp ")"
//         //    | @categoryTerm="keyword.operator" Exp "in" !>>[a-z0-9] Exp 
//            ;

// lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
// keyword KW = "for"|"in"|"if"|"true"|"false"|"else";

// layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
// lexical WhitespaceAndComment 
//    = [\ \t\n\r]
//    | @category="comment.block" "%" !>> "%" ![%]+ "%"
//    | @category="comment.line" "%%" ![\n]* $
//    ;



void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = false;

    log = standardLogger();
    list[Warning] cWarnings = [], 
                  rWarnings = [], 
                  pWarnings = [], 
                  sWarnings = [], 
                  mWarnings = [];
    ConversionGrammar inputGrammar, conversionGrammar;
    if(recalc) {
        c = testConfig(log = log);
        <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, c);
        <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, c);
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
    }

    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    
    <inputGrammar, symMap> = relabelGeneratedSymbolsWithMapping(conversionGrammar);

    <mWarnings, scopeGrammar> = toScopeGrammar(conversionGrammar, log);
    tmGrammar = createTextmateGrammar(scopeGrammar, highlightGrammarData(
        "highlight",
        [<parseRegexReduced("[(]"), parseRegexReduced("[)]")>],
        scopeName="source.highlight"
    ));


    warnings = cWarnings + rWarnings + pWarnings + sWarnings + mWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        tmGrammar,
        warnings,
        conversionGrammar.\start,
        symMap
    >);

    
    loc output = |project://syntax-highlighter/outputs/tmGrammar.json|;
    writeJSON(output, tmGrammar, indent=4);
}