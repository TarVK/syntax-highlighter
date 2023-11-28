module testing::automated::setup::runRobustnessTest
extend testing::automated::setup::calculateInputData;

import IO;
import ValueIO;
import Location;

import Visualize;
import Warning;
import TestConfig;
import testing::automated::setup::calculateInputData;
import testing::automated::setup::runTest;


@doc {
    Tests the accuracy of this grammar on the inputs provided in the folder and logs the results
}
bool runRobustnessTest(GrammarSpec spec, str inputName, Tokenization specTokenization) 
    = runRobustnessTest(spec, inputName, specTokenization, autoTestConfig());
bool runRobustnessTest(GrammarSpec spec, str inputName, Tokenization specTokenization, AutomatedTestConfig autoTestConfig) {
    grammarTree = spec.grammar;
    inputFolder = spec.inputFolder;
    inputName += ".txt";

    InputData inputData = calculateInputData(
        grammarTree, 
        inputFolder, 
        inputName, 
        Tokenization (Grammar grammar, str text) {
            return specTokenization;
        },
        autoTestConfig);

    pd = inputData.precisionData;
    return pd.correct == pd.total;
}
