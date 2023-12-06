module convertGrammar

import Grammar;
import String;
import lang::json::IO;
import ValueIO;

import Warning;
import Logging;
import TestConfig;

import regex::Regex;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import specTransformations::GrammarTransformer;
import conversion::regexConversion::convertToRegularExpressions;
import conversion::prefixConversion::convertToPrefixed;
import conversion::shapeConversion::convertToShape;
import conversion::util::transforms::relabelSymbols;
import conversion::util::transforms::removeUnreachable;
import conversion::util::transforms::removeAliases;
import determinism::check::checkDeterminism;
import mapping::common::HighlightGrammarData;
import mapping::intermediate::scopeGrammar::toScopeGrammar;
import mapping::intermediate::PDAGrammar::toPDAGrammar;
import mapping::intermediate::PDAGrammar::ScopeMerging;
import mapping::textmate::createTextmateGrammar;
import mapping::monarch::createMonarchGrammar;
import mapping::pygments::createPygmentsGrammar;
import mapping::ace::createAceGrammar;


data OutputType = conversionGrammarOutput()
                | textmateGrammarOutput()
                | monarchGrammarOutput()
                | aceGrammarOutput()
                | pygmentsGrammarOutput();

data ConversionConfig(
    GrammarTransformer addCategories = transformerIdentity,
    GrammarTransformer addLookaheads = transformerIdentity,
    HighlightGrammarData highlightData = highlightGrammarData(
        "test",
        [<parseRegexReduced("[(]"), parseRegexReduced("[)]")>],
        scopeName="source.test"
    ),
    TestConfig testConfig = testConfig(),
    ScopeMerger merge = useLastScope("text"),
    bool outputOnlyErrors = true
) = config(type[Tree] grammarTree, loc location, set[OutputType] target)
  | configGrammar(Grammar grammar, loc location, set[OutputType] target);

@doc {
    Performs the complete conversion algorithm 
}
list[Warning] convertGrammar(ConversionConfig config) {
    TestConfig testConfig = config.testConfig;
    log = testConfig.log;
    location = config.location;
    list[Warning] warnings = [];
    list[Warning] outputConv() {
        writeBinaryValueFile(location+"conversionGrammar.bin", conversionGrammar);
        writeTextValueFile(location+"warnings.txt", warnings);
        return warnings;
    }

    // Create the conversion grammar
    <cWarnings, conversionGrammar> = toConversionGrammar(
            configGrammar(grammar, _, _) := config? grammar: config.grammarTree, 
            log
        );
    conversionGrammar = config.addCategories(conversionGrammar, log);

    // Primary language conversion
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
    if(regexConversion() := testConfig.lastPhase) return outputConv();
    conversionGrammar = config.addLookaheads(conversionGrammar, log);
    if(lookaheadAdding() := testConfig.lastPhase) return outputConv();
    <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, testConfig);
    if(prefixConversion() := testConfig.lastPhase) return outputConv();
    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, testConfig);
    if(shapeConversion() := testConfig.lastPhase) return outputConv();

    // Post processing and safety checking
    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    <conversionGrammar, _> = relabelGeneratedSymbolsWithMapping(conversionGrammar);
    dWarnings = checkDeterminism(conversionGrammar, log);
    if(cleanup() := testConfig.lastPhase) return outputConv();

    // Grammar mapping
    <mWarnings, scopeGrammar> = toScopeGrammar(conversionGrammar, log);
    warnings = cWarnings + rWarnings + pWarnings + sWarnings + dWarnings + mWarnings;
    if(textmateGrammarOutput() <- config.target) {
        log(Section(), "creating TextMate grammar");
        tmGrammar = createTextmateGrammar(scopeGrammar, config.highlightData);
        writeJSON(location+"tmGrammar.json", tmGrammar, indent=4);
    }
    if(
        scopeGrammarCreation() !:= testConfig.lastPhase
        && (
            monarchGrammarOutput() <- config.target 
        || aceGrammarOutput() <- config.target 
        || pygmentsGrammarOutput() <- config.target
        )
    ){
        <aWarnings, PDAGrammar> = toPDAGrammar(scopeGrammar, config.merge, log);

        warnings += aWarnings;
        if(monarchGrammarOutput() <- config.target) {
            log(Section(), "creating Monarch grammar");
            monarchGrammar = createMonarchGrammar(PDAGrammar);
            writeJSON(location+"monarchGrammar.json", monarchGrammar, indent=4);
        }
        if(aceGrammarOutput() <- config.target) {
            log(Section(), "creating Ace grammar");
            aceGrammar = createAceGrammar(PDAGrammar);
            writeJSON(location+"aceGrammar.json", aceGrammar, indent=4);
        }
        if(pygmentsGrammarOutput() <- config.target) {
            log(Section(), "creating Pygments grammar");
            pygmentsGrammar = createPygmentsGrammar(PDAGrammar);
            writeJSON(location+"pygmentsGrammar.json", pygmentsGrammar, indent=4);
        }
    }
    if(conversionGrammarOutput() <- config.target)
        outputConv();
    
    // Filter warnings for errors
    if(config.outputOnlyErrors)
        warnings = [warning | warning <- warnings, isError(warning)];

    log(Section(), "conversion finished");
    return warnings;
}