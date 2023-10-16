module testing::fullConversionTest

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
import mapping::intermediate::scopeGrammar::toScopeGrammar;
import mapping::textmate::createTextmateGrammar;
import mapping::common::HighlightGrammarData;
import Warning;

import testing::grammars::StructuredLanguage;
// import testing::grammars::SimpleLanguage;
// import testing::grammars::LambdaLanguage;


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
        addGrammarTokens = transformerUnion([
            addKeywordTokens(exceptKeywordsProductions(allProductions)),
            addOperatorTokens(exceptKeywordsProductions(allProductions))
        ]);
        conversionGrammar = addGrammarTokens(conversionGrammar, log);

        inputGrammar = conversionGrammar;
        <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
        // conversionGrammar              = addGrammarLookaheads(conversionGrammar, 1, log);
        // conversionGrammar              = addNegativeCharacterGrammarLookaheads(conversionGrammar, {parseRegexReduced("[a-zA-Z0-9]")}, log);
        writeBinaryValueFile(pos, conversionGrammar);
    } else {
        conversionGrammar = readBinaryValueFile(#ConversionGrammar,  pos);
        inputGrammar = conversionGrammar;
    }

    conversionGrammar              = addDynamicGrammarLookaheads(conversionGrammar, {parseRegexReduced("[a-zA-Z0-9]")}, log);
    writeBinaryValueFile(pos, conversionGrammar);

    <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, log);
    writeBinaryValueFile(pos, conversionGrammar);

    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, log);

    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    <conversionGrammar, symMap> = relabelGeneratedSymbolsWithMapping(conversionGrammar);
    dWarnings = checkDeterminism(conversionGrammar, log);

    <mWarnings, scopeGrammar> = toScopeGrammar(conversionGrammar, log);
    tmGrammar = createTextmateGrammar(scopeGrammar, highlightGrammarData(
        "highlight",
        [<parseRegexReduced("[(]"), parseRegexReduced("[)]")>],
        scopeName="source.highlight"
    ));

    log(Section(), "finished");
    
    loc output = |project://syntax-highlighter/outputs/tmGrammar.json|;
    writeJSON(output, tmGrammar, indent=4);

    log(Section(), "saved");

    warnings = cWarnings + rWarnings + pWarnings + sWarnings + mWarnings + dWarnings;
    visualizeGrammars(<
        fromConversionGrammar(inputGrammar),
        fromConversionGrammar(conversionGrammar),
        warnings,
        conversionGrammar.\start,
        symMap
    >);
}