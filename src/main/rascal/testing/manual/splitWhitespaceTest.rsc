module testing::manual::splitWhitespaceTest

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
import determinism::improvement::addGrammarLookaheads;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::intermediate::scopeGrammar::toScopeGrammar;

import conversion::util::equality::getEquivalentSymbols;
import Warning;
import TestConfig;

// import testing::grammars::SimpleScoped1;

syntax Program = Stmt*;
syntax Stmt = Type Variable "=" Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

syntax Type = \type: TypeVariable
            | ar: Type "[]"
            | apply: Type "\<" {Type ","}+ "\>"
            | @categoryTerm="primitive" number: "number"
            | @categoryTerm="primitive" string: "string"
            | @categoryTerm="primitive" boolean: "bool";

lexical Variable = @category="variable" Id;
lexical TypeVariable = @category="type" Id;

keyword KW = "bool"|"number"|"string";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout        = [\ \t]* !>> [\ \t\n\r]
                     | [\ \t]*[\n\r][\ \t\n\r]* !>> [\ \t\n\r];



void main() {
    loc pos = |project://syntax-highlighter/outputs/shapeConversionGrammar.bin|;
    bool recalc = false;

    log = standardLogger();
    list[Warning] cWarnings, rWarnings, pWarnings, sWarnings;
    ConversionGrammar inputGrammar, conversionGrammar;
    if(recalc) {
        <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        conversionGrammar = addGrammarLookaheads(conversionGrammar, 1, log);
        inputGrammar = conversionGrammar;
        <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, log);
        <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, testConfig(log = log));
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
        cWarnings = rWarnings = pWarnings = [];
    }


    // Simplify for readability
    conversionGrammar = replaceNfaByRegex(conversionGrammar);
    conversionGrammar = removeUnreachable(conversionGrammar);
    <conversionGrammar, symMap> = relabelGeneratedSymbolsWithMapping(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    
    <mWarnings, scopeGrammar> = toScopeGrammar(conversionGrammar, log);

    warnings = cWarnings + rWarnings + pWarnings + sWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings,
        conversionGrammar.\start
        , symMap
    >);
}