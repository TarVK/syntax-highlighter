module testing::manual::pygmentsTest

import ValueIO;
import lang::json::IO;

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import specTransformations::tokenAugmenters::addKeywordTokens;
import specTransformations::tokenAugmenters::addOperatorTokens;
import specTransformations::transformerUnion;
import specTransformations::productionRetrievers::allProductions;
import specTransformations::productionRetrievers::exceptKeywordsProductions;
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
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::intermediate::scopeGrammar::toScopeGrammar;
import mapping::intermediate::PDAGrammar::toPDAGrammar;
import mapping::intermediate::PDAGrammar::ScopeMerging;
import mapping::common::HighlightGrammarData;
import mapping::pygments::createPygmentsGrammar;

import Warning;
import TestConfig;

// import testing::grammars::SimpleLanguage;


syntax Program = Stmt*;
syntax Stmt = iff: If "(" Exp ")" Stmt
            | assign: Def "=" Exp ";";

syntax Exp = @categoryTerm="variable.parameter" brac: "(" Exp ")"
           | @categoryTerm="keyword.operator" add: Exp "+" Exp
           | @categoryTerm="keyword.operator" mult: Exp "*" Exp
           | @categoryTerm="keyword.operator" subt: Exp "-" Exp
           | @categoryTerm="keyword.operator" divide: Exp "/" Exp
           | @categoryTerm="keyword.operator" equals: Exp "==" Exp
           | @categoryTerm="keyword.operator" inn: Exp "in" Exp
           | var: Variable
           | string: Str
           | booll: Bool !>> [0-9a-z]
           | nat: Natural;

lexical If = @categoryTerm="keyword" "if";
lexical Sep = @categoryTerm="entity.name.function" ";";
lexical Def = @category="variable.parameter" Id;
lexical Variable = @category="variable" Id;

keyword KW = "for"|"in"|"if"|"true"|"false"|"else";
lexical Id = ([a-z] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;
lexical Natural = @category="constant.numeric" [0-9]+ !>> [a-z0-9];
lexical Bool = @category="constant.other" ("true"|"false");
lexical Str = @category="string.template" string: "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @categoryTerm="constant.character.escape" escape: "\\"![]
             | @category="meta.embedded.line" @categoryTerm="punctuation.definition.template-expression" embedded: "${" Layout Exp Layout "}";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="comment.block" "%" ![%]+ "%"
   | @category="comment.line" "%%" ![\n]* $
   ;


void main() {
    loc pos = |project://syntax-highlighter/outputs/scopeGrammar.bin|;
    bool recalc = false;

    log = standardLogger();
    list[Warning] cWarnings = [], 
                  rWarnings = [], 
                  pWarnings = [], 
                  sWarnings = [], 
                  mWarnings = [],
                  dWarnings = [],
                  aWarnings = [];
    ConversionGrammar inputGrammar, conversionGrammar;
    ScopeGrammar scopeGrammar;

    <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);    
    inputGrammar = conversionGrammar;

    if(recalc) {
        // addGrammarTokens = transformerUnion([
        //     addKeywordTokens(exceptKeywordsProductions(allProductions)),
        //     addOperatorTokens(exceptKeywordsProductions(allProductions))
        // ]);
        // conversionGrammar = addGrammarTokens(conversionGrammar, log);

        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        // conversionGrammar              = addGrammarLookaheads(conversionGrammar, 1, log);
        // conversionGrammar              = addNegativeCharacterGrammarLookaheads(conversionGrammar, {parseRegexReduced("[a-zA-Z0-9]")}, log);

        conversionGrammar              = addDynamicGrammarLookaheads(conversionGrammar, {parseRegexReduced("[a-zA-Z0-9]")}, log);
        writeBinaryValueFile(pos, conversionGrammar);

        c = testConfig(log = log);
        <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, c);
        writeBinaryValueFile(pos, conversionGrammar);

        <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, c);

        conversionGrammar = removeUnreachable(conversionGrammar);
        conversionGrammar = removeAliases(conversionGrammar);
        <conversionGrammar, symMap> = relabelGeneratedSymbolsWithMapping(conversionGrammar);
        dWarnings = checkDeterminism(conversionGrammar, log);

        <mWarnings, scopeGrammar> = toScopeGrammar(conversionGrammar, log);

        writeBinaryValueFile(pos, scopeGrammar);
    } else {
        scopeGrammar = readBinaryValueFile(#ScopeGrammar,  pos);
    }

    <aWarnings, PDAGrammar> = toPDAGrammar(scopeGrammar, useLastScope("text"), log);
    pygmentsGrammar = createPygmentsGrammar(PDAGrammar);

    log(Section(), "finished");
    
    loc output = |project://syntax-highlighter/outputs/pygmentsGrammar.json|;
    writeJSON(output, pygmentsGrammar, indent=4);

    log(Section(), "saved");

    warnings = cWarnings + rWarnings + pWarnings + sWarnings + mWarnings + dWarnings + aWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings,
        conversionGrammar.\start
    >);
}