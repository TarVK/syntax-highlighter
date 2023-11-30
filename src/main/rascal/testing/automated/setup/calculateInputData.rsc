module testing::automated::setup::calculateInputData

import IO;
import ParseTree;
import Location;
import lang::json::IO;
import ValueIO;
import util::Math;
import util::ShellExec;
import String;
import List;
import DateTime;
import Grammar;

import Warning;
import TestConfig;
import Logging;
import convertGrammar;
import conversion::conversionGrammar::ConversionGrammar;
import testing::automated::setup::checkPrecision;
import regex::RegexCache;
import regex::RegexStripping;
import regex::PSNFA;
import regex::Regex;
import Scope;
import determinism::improvement::addDynamicGrammarLookaheads;
import specTransformations::GrammarTransformer;

data InputData = inputData(
    list[Warning] warnings,
    Tokenization spec,
    Tokenization result,
    PrecisionData precisionData,
    str inputText
);

data AutomatedTestConfig(
    // Add categories is not supported, since it operates on a conversion grammar, rather than the spec
    // GrammarTransformer addCategories = transformerIdentity,
    GrammarTransformer addLookaheads = defaultAddLookaheads,
    Grammar(Grammar) transformSpec = Grammar (Grammar grammar) { return grammar; },
    TestConfig testConfig = testConfig(),
    set[OutputType] outputs = {}
) = autoTestConfig();

public GrammarTransformer defaultAddLookaheads = ConversionGrammar (ConversionGrammar conversionGrammar, Logger log) {
    return addDynamicGrammarLookaheads(conversionGrammar, {
        parseRegexReduced("[a-zA-Z0-9]"),
        parseRegexReduced("[=+\\-\<\>]")
    }, log);
};

@doc {
    Calculates tokenization and precision data for a given input file and a given grammar
}
InputData calculateInputData(type[Tree] grammarTree, loc inputFolder, str inputName) 
    = calculateInputData(grammarTree, inputFolder, inputName, autoTestConfig());
InputData calculateInputData(type[Tree] grammarTree, loc inputFolder, str inputName, AutomatedTestConfig autoTestConfig)
    = calculateInputData(
        grammarTree, 
        inputFolder, 
        inputName, 
        Tokenization (Grammar grammar, str text) {
            return getTokenization(grammar, text);
        }, 
        autoTestConfig);
InputData calculateInputData(type[Tree] grammarTree, loc inputFolder, str inputName, Tokenization (Grammar, str) getTokenizationFunc, AutomatedTestConfig autoTestConfig) {
    generatePath = getGeneratePath(inputFolder);

    entries = listEntries(inputFolder);
    if(grammarPath <- entries, (inputFolder + grammarPath).extension=="rsc") {
        grammar = getGrammar(grammarTree, autoTestConfig);

        // Get spec tokenization    
        println("Obtaining specification tokenization for <inputName>");
        copyFile(inputFolder + inputName, generatePath+inputName);

        inputText = readFile(generatePath + inputName);
        tokenizationPath = generatePath+inputName;
        tokenizationPath.extension = "tokens.spec.json";
        tokenizationSpec = getTokenizationFunc(grammar, inputText);
        writeJSON(tokenizationPath, tokenizationSpec, indent=4);

        // Get output grammar
        warnings = calculateGrammar(grammarTree, inputFolder, autoTestConfig);

        // Get resulting tokenization, using the nodejs script that generates tokenization json files
        args = [getAbsolutePath(generatePath +"tmGrammar.json"), getAbsolutePath(generatePath + inputName)];
        programPath = getAbsolutePath(|project://syntax-highlighter/highlighterTesting/textmate/automated/build/index.js|);
        <result, code> = execWithCode("node", args = [programPath] + args);
        
        tokenizationPath = generatePath+inputName;
        tokenizationPath.extension = "tokens.json";
        tokenization = readJSON(#Tokenization, tokenizationPath);

        precision = checkPrecision(inputText, tokenizationSpec, tokenization);

        // Output results
        return inputData(warnings, tokenizationSpec, tokenization, precision, inputText);
    }

    return inputData([], [], [], precisionData(0, 0, []), "");
}

loc getGeneratePath(loc inputFolder) {
    relativePath = relativize(|project://syntax-highlighter/src/main/rascal/testing/automated/|, inputFolder);
    return |project://syntax-highlighter/outputs| + relativePath.path;
}

Grammar getGrammar(type[Tree] grammarTree,  AutomatedTestConfig autoTestConfig) {
    grammar = grammar(grammarTree);
    return autoTestConfig.transformSpec(grammar);
}


list[Warning] calculateGrammar(type[Tree] grammarTree, loc inputFolder, AutomatedTestConfig autoTestConfig)
    = calculateGrammar(grammarTree, inputFolder, autoTestConfig, {textmateGrammarOutput()});
list[Warning] calculateGrammar(type[Tree] grammarTree, loc inputFolder, AutomatedTestConfig autoTestConfig, set[OutputType] outputs) {
    outputs += autoTestConfig.outputs;
    generatePath = getGeneratePath(inputFolder);
    grammar = getGrammar(grammarTree, autoTestConfig);

    entries = listEntries(inputFolder);
    if(grammarPath <- entries, (inputFolder + grammarPath).extension=="rsc") {
        list[Warning] warnings = [];
        modifiedDate = lastModified(inputFolder + grammarPath);
        outGrammarPath = generatePath +"tmGrammar.json";
        if(!exists(outGrammarPath) || lastModified(outGrammarPath) < modifiedDate) {
            startTime = now();
            warnings = insertPSNFADiagrams(stripSources(removeInnerRegexCache(
                convertGrammar(configGrammar(
                    grammar,
                    generatePath, // tmGrammar.json is the hardcoded name of generated TM grammars (indeed, hardcoding should be fixed)
                    outputs,
                    // addCategories = autoTestConfig.addCategories,
                    addLookaheads = autoTestConfig.addLookaheads,
                    testConfig = autoTestConfig.testConfig
                ))
            )));
            generationTime = now() - startTime;
            gd = grammarData(formatDuration(generationTime), warnings);
            writeTextValueFile(generatePath+"grammarData.txt", gd);
            writeBinaryValueFile(generatePath+"grammarData.bin", gd);
        } else {
            gd = readBinaryValueFile(#GrammarData, generatePath+"grammarData.bin");
            warnings = gd.warnings;
        }

        return warnings;
    }
    return [];
}

data GrammarData = grammarData(str generationTime, list[Warning] warnings);

str getAbsolutePath(loc location) = substring(resolveLocation(location).path, 1);

str formatDuration(duration(years, months, days, hours, minutes, seconds, milliseconds)) 
    = "<((((years * 12 + months) * 30 + days) * 24 + hours) * 60 + minutes)>:<right("<seconds>", 2, "0")>.<substring("<precision(toReal(milliseconds)/1000, 4)>", 2)>";