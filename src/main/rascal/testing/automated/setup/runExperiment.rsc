module testing::automated::setup::runExperiment
extend testing::automated::setup::calculateInputData;

import IO;
import ValueIO;
import Location;

import Visualize;
import Warning;
import TestConfig;
import testing::automated::setup::calculateInputData;


@doc {
    Tests the accuracy of this grammar on the inputs provided in the folder and logs the results
}
list[Warning] runExperiment(type[Tree] grammar, loc inputFolder) 
    = runExperiment(grammar, inputFolder, autoTestConfig());

list[Warning] runExperiment(type[Tree] grammarTree, loc inputFolder, AutomatedTestConfig autoTestConfig) {
    relativePath = relativize(|project://syntax-highlighter/src/main/rascal/testing/automated/|, inputFolder);
    generatePath = |project://syntax-highlighter/outputs|+relativePath.path;

    entries = listEntries(inputFolder);
    inputs = {entry | entry<-entries, (inputFolder + entry).extension=="txt"};
    
    list[Warning] warnings = [];
    str results = "";
    map[str, tuple[list[TokenizationGroup], str]] allErrors = ();
    for(input <- inputs) {
        InputData inputData = calculateInputData(grammarTree, inputFolder, input, autoTestConfig);
        warnings = inputData.warnings;
        if(precisionData(correct, total, errors) := inputData.precisionData) {
            allErrors[input] = <errors, inputData.inputText>;

            text = "<input>: <correct>/<total>, <precision(toReal(correct)/toReal(total)*100, 4)>%";
            results += text + "\n";
            println(text);
        } else throw "error";
    }
    writeFile(generatePath+"results.txt", results);
    writeTextValueFile(generatePath+"differences.txt", allErrors);
    visualize(<allErrors, warnings>);
    return warnings;
}