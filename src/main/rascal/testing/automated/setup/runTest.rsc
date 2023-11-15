module testing::automated::setup::runTest

import IO;
import ParseTree;
import Location;
import lang::json::IO;
import util::Math;
import util::ShellExec;
import String;
import List;

import convertGrammar;
import conversion::conversionGrammar::ConversionGrammar;
import Logging;
import specTransformations::GrammarTransformer;
import testing::automated::setup::checkPrecision;
import Scope;

import regex::Regex;
import determinism::improvement::addDynamicGrammarLookaheads;

data GrammarProcessors(
    GrammarTransformer addCategories = transformerIdentity,
    GrammarTransformer addLookaheads = transformerIdentity
) = grammarProcessors();

@doc {
    Tests the accuracy of this grammar on the inputs provided in the folder and logs the results
}
void runTest(type[Tree] grammar, loc inputFolder) 
    = runTest(grammar, inputFolder, grammarProcessors(
        addLookaheads = ConversionGrammar (ConversionGrammar conversionGrammar, Logger log) {
            return addDynamicGrammarLookaheads(conversionGrammar, {
                parseRegexReduced("[a-zA-Z0-9]"),
                parseRegexReduced("[=]")
            }, log);
        }
    ));

void runTest(type[Tree] grammar, loc inputFolder, GrammarProcessors processors) {
    relativePath = relativize(|project://syntax-highlighter/src/main/rascal/testing/automated/|, inputFolder);
    generatePath = |project://syntax-highlighter/outputs|+relativePath.path;

    map[str, Tokenization] spec = ();
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
        spec[input] = inputSpec;
    }

    if(grammarPath <- entries, (inputFolder + grammarPath).extension=="rsc") {
        modifiedDate = lastModified(inputFolder + grammarPath);
        outGrammarPath = generatePath +"tmGrammar.json";
        if(!exists(outGrammarPath) || lastModified(outGrammarPath) < modifiedDate) {
            warnings = convertGrammar(config(
                grammar,
                generatePath, // tmGrammar.json is the hardcoded name of generated TM grammars (indeed, hardcoding should be fixed)
                {textmateGrammarOutput()},
                addLookaheads = processors.addLookaheads,
                addCategories = processors.addCategories
            ));
            writeJSON(generatePath+"warnings.json", warnings, indent=4);
        }

        args = [getAbsolutePath(outGrammarPath)];
        for(input <- inputs)
            args += getAbsolutePath(generatePath + input);
        programPath = getAbsolutePath(|project://syntax-highlighter/highlighterTesting/textmate/automated/build/index.js|);
        <result, code> = execWithCode("node", args = [programPath] + args);
        
        str results = "";
        for(input <- inputs) {
            tokenizationPath = generatePath+input;
            tokenizationPath.extension = "tokens.json";
            tokenization = readJSON(#Tokenization, tokenizationPath);

            correct = checkPrecision(spec[input], tokenization);

            text = "<input>: <correct>/<size(tokenization)>, <precision(toReal(correct)/toReal(size(tokenization))*100, 4)>%";
            results += text + "\n";
            println(text);
        }
        writeFile(generatePath+"results.txt", results);
    }
}

str getAbsolutePath(loc location) = substring(resolveLocation(location).path, 1);