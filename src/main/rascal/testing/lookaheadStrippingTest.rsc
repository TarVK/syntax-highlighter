module testing::lookaheadStrippingTest

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
import determinism::improvement::addGrammarLookaheads;
import determinism::improvement::addNegativeCharacterGrammarLookaheads;
import determinism::improvement::addDynamicGrammarLookaheads;
import determinism::check::checkDeterminism;
import regex::Regex;


import conversion::util::equality::getEquivalentSymbols;
import Warning;

import testing::grammars::SimpleScoped2;

// syntax Program = Stmt*;
// syntax Stmt = exp: Exp
//             // | @token="keyword" iff: "if" >> ("("|[\n\ ]) "(" Exp ")" Stmt
//             // | iff: "if" "(" Exp ")" Stmt "else" !>> [a-z0-9] Stmt
//             // | iff: "if" >> ("("|[\n\ ]) Stmt
//             // | iff: "if" Stmt "else" Stmt
//             // | @token="KW" "in" !>> [a-z0-9]
//             | forIn: "for" "(" Id "in" Exp ")" Stmt
//             | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt
//             // | forIn: "for" >> ("("|[\n\ ]) "(" Exp "in" !>> [a-z0-9] Id ")" Stmt
//             // | forIter: "for" >> ("("|[\n\ ]) "(" Exp ";" Exp ";" Exp ")" Stmt
//             // | forIn: "(" "in" !>> [a-z0-9] Exp ")" Stmt
//             // | forIn: "(" Exp ")" Stmt
//             ;
// syntax Exp = id: Id
//            | brackets: "(" Exp ")"
//         //    | @token="keyword.operator" Exp "in" Exp 
//            ;

// lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
// keyword KW = "for"|"in"|"if"|"true"|"false"|"else";

// layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
// lexical WhitespaceAndComment 
//    = [\ \t\n\r]
//    | @scope="comment.block" "%" ![%]+ "%"
//    | @scope="comment.line" "%%" ![\n]* $
//    ;

void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = true;

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
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        // conversionGrammar              = addGrammarLookaheads(conversionGrammar, 1, log);
        // conversionGrammar              = addNegativeCharacterGrammarLookaheads(conversionGrammar, {parseRegexReduced("[a-zA-Z0-9]")}, log);
        conversionGrammar              = addDynamicGrammarLookaheads(conversionGrammar, {parseRegexReduced("[a-zA-Z0-9]")}, log);
        <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, log);
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
        inputGrammar = conversionGrammar;
    }

    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, log);

    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    <conversionGrammar, symMap> = relabelGeneratedSymbolsWithMapping(conversionGrammar);
    dWarnings = checkDeterminism(conversionGrammar, log);
    log(Section(), "finished");

    warnings = cWarnings + rWarnings + pWarnings + sWarnings + mWarnings + dWarnings;
    visualizeGrammars(<
        (),
        fromConversionGrammar(conversionGrammar),
        warnings,
        conversionGrammar.\start,
        symMap
    >);
}