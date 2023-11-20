module testing::automated::setup::runTest

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

import Visualize;
import Warning;
import TestConfig;
import convertGrammar;
import conversion::conversionGrammar::ConversionGrammar;
import Logging;
import specTransformations::GrammarTransformer;
import testing::automated::setup::checkPrecision;
import Scope;
import regex::RegexCache;
import regex::RegexStripping;
import regex::PSNFA;
import regex::Regex;
import determinism::improvement::addDynamicGrammarLookaheads;

data AutomatedTestConfig(
    // Add categories is not supported, since it operates on a conversion grammar, rather than the spec
    // GrammarTransformer addCategories = transformerIdentity,
    GrammarTransformer addLookaheads = defaultAddLookaheads,
    Grammar(Grammar) transformSpec = Grammar (Grammar grammar) { return grammar; },
    TestConfig testConfig = testConfig()
) = autoTestConfig();

public GrammarTransformer defaultAddLookaheads = ConversionGrammar (ConversionGrammar conversionGrammar, Logger log) {
    return addDynamicGrammarLookaheads(conversionGrammar, {
        parseRegexReduced("[a-zA-Z0-9]"),
        parseRegexReduced("[=+\\-\<\>]")
    }, log);
};

@doc {
    Tests the accuracy of this grammar on the inputs provided in the folder and logs the results
}
list[Warning] runTest(type[Tree] grammar, loc inputFolder) 
    = runTest(grammar, inputFolder, autoTestConfig());

list[Warning] runTest(type[Tree] grammarTree, loc inputFolder, AutomatedTestConfig autoTestConfig) {
    relativePath = relativize(|project://syntax-highlighter/src/main/rascal/testing/automated/|, inputFolder);
    generatePath = |project://syntax-highlighter/outputs|+relativePath.path;

    
    grammar = grammar(grammarTree);
    grammar = autoTestConfig.transformSpec(grammar);

    map[str, tuple[str, Tokenization]] spec = ();
    entries = listEntries(inputFolder);
    inputs = {entry | entry<-entries, (inputFolder + entry).extension=="txt"};
    for(input <- inputs) {
        println("Obtaining specification tokenization for <input>");
        copyFile(inputFolder + input, generatePath+input);

        inputText = readFile(generatePath + input);
        tokenizationPath = generatePath+input;
        tokenizationPath.extension = "tokens.spec.json";
        inputSpec = getTokenization(grammar, inputText);
        writeJSON(tokenizationPath, inputSpec, indent=4);
        spec[input] = <inputText, inputSpec>;
    }

    list[Warning] warnings = [];
    if(grammarPath <- entries, (inputFolder + grammarPath).extension=="rsc") {
        modifiedDate = lastModified(inputFolder + grammarPath);
        outGrammarPath = generatePath +"tmGrammar.json";
        if(!exists(outGrammarPath) || lastModified(outGrammarPath) < modifiedDate) {
            startTime = now();
            warnings = insertPSNFADiagrams(stripSources(removeInnerRegexCache(
                convertGrammar(configGrammar(
                    grammar,
                    generatePath, // tmGrammar.json is the hardcoded name of generated TM grammars (indeed, hardcoding should be fixed)
                    {textmateGrammarOutput()},
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

        args = [getAbsolutePath(outGrammarPath)];
        for(input <- inputs)
            args += getAbsolutePath(generatePath + input);
        programPath = getAbsolutePath(|project://syntax-highlighter/highlighterTesting/textmate/automated/build/index.js|);
        <result, code> = execWithCode("node", args = [programPath] + args);
        
        str results = "";
        map[str, value] allErrors = ();
        for(input <- inputs) {
            tokenizationPath = generatePath+input;
            tokenizationPath.extension = "tokens.json";
            tokenization = readJSON(#Tokenization, tokenizationPath);

            <inputText, specTokens> = spec[input];
            <correct, errors> = checkPrecision(inputText, specTokens, tokenization);
            allErrors[input] = errors;

            text = "<input>: <correct>/<size(tokenization)>, <precision(toReal(correct)/toReal(size(tokenization))*100, 4)>%";
            results += text + "\n";
            println(text);
        }
        writeFile(generatePath+"results.txt", results);
        writeTextValueFile(generatePath+"differences.txt", allErrors);
        visualize(<allErrors, warnings>);
    }

    return warnings;
}

data GrammarData = grammarData(str generationTime, list[Warning] warnings);

str getAbsolutePath(loc location) = substring(resolveLocation(location).path, 1);

str formatDuration(duration(years, months, days, hours, minutes, seconds, milliseconds)) 
    = "<((((years * 12 + months) * 30 + days) * 24 + hours) * 60 + minutes)>:<right("<seconds>", 2, "0")>.<substring("<precision(toReal(milliseconds)/1000, 4)>", 2)>";