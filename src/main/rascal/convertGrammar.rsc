module convertGrammar

import Grammar;
import String;
import lang::json::IO;
import ValueIO;

import Warning;
import Logging;

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
    Logger log = standardLogger(),
    GrammarTransformer addCategories = transformerIdentity,
    GrammarTransformer addLookaheads = transformerIdentity,
    HighlightGrammarData highlightData = highlightGrammarData(
        "test",
        [<parseRegexReduced("[(]"), parseRegexReduced("[)]")>],
        scopeName="source.test"
    ),
    ScopeMerger merge = useLastScope("text"),
    bool outputOnlyErrors = true
) = config(type[Tree] grammar, loc location, set[OutputType] target);

@doc {
    Performs the complete conversion algorithm 
}
list[Warning] convertGrammar(ConversionConfig config) {
    log = config.log;

    // Create the conversion grammar
    <cWarnings, conversionGrammar> = toConversionGrammar(config.grammar, log);
    conversionGrammar = config.addCategories(conversionGrammar, log);

    // Primary language conversion
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
    conversionGrammar = config.addLookaheads(conversionGrammar, log);
    <pWarnings, conversionGrammar> = convertToPrefixed(conversionGrammar, log);
    <sWarnings, conversionGrammar> = convertToShape(conversionGrammar, log);

    // Post processing and safety checking
    conversionGrammar = removeUnreachable(conversionGrammar);
    conversionGrammar = removeAliases(conversionGrammar);
    <conversionGrammar, _> = relabelGeneratedSymbolsWithMapping(conversionGrammar);
    dWarnings = checkDeterminism(conversionGrammar, log);

    // Grammar mapping
    location = config.location;
    <mWarnings, scopeGrammar> = toScopeGrammar(conversionGrammar, log);
    list[Warning] warnings = cWarnings + rWarnings + pWarnings + sWarnings + dWarnings + mWarnings;
    if(textmateGrammarOutput() <- config.target) {
        log(Section(), "creating TextMate grammar");
        tmGrammar = createTextmateGrammar(scopeGrammar, config.highlightData);
        writeJSON(location+"tmGrammar.json", tmGrammar, indent=4);
    }
    if(
        monarchGrammarOutput() <- config.target,
        aceGrammarOutput() <- config.target,
        pygmentsGrammarOutput() <- config.target
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
        writeBinaryValueFile(location+"conversionGrammar.bin", scopeGrammar);
    
    // Filter warnings for errors
    if(config.outputOnlyErrors)
        warnings = [warning | warning <- warnings, isError(warning)];

    log(Section(), "conversion finished");
    return warnings;
}