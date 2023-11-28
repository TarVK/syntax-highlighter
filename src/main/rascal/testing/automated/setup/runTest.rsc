module testing::automated::setup::runTest
extend testing::automated::setup::calculateInputData;

import IO;
import ValueIO;
import Location;

import Visualize;
import Warning;
import TestConfig;
import testing::automated::setup::calculateInputData;
import testing::automated::setup::checkPrecision;


alias GrammarSpec = tuple[type[Tree] grammar, loc inputFolder];

@doc {
    Tests the accuracy of this grammar on the inputs provided in the folder and logs the results
}
bool runTest(GrammarSpec spec, str inputName) 
    = runTest(spec, inputName, false, autoTestConfig());
bool runTest(GrammarSpec spec, str inputName, bool negativeTest) 
    = runTest(spec, inputName, negativeTest, autoTestConfig());
bool runTest(GrammarSpec spec, str inputName, AutomatedTestConfig autoTestConfig) 
    = runTest(spec, inputName, false, autoTestConfig);
bool runTest(GrammarSpec spec, str inputName, bool negativeTest, AutomatedTestConfig autoTestConfig) {
    InputData inputData = calculateInputData(spec.grammar, spec.inputFolder, inputName+".txt", Tokenization (Grammar grammar, str text) {
        return getTokenization(grammar, text);
    }, autoTestConfig);

    pd = inputData.precisionData;
    correctlyTokenized = pd.correct == pd.total;
    
    return negativeTest ? !correctlyTokenized : correctlyTokenized;
}

list[Warning] getWarnings(GrammarSpec spec)
    = getWarnings(spec, autoTestConfig());
list[Warning] getWarnings(GrammarSpec spec, AutomatedTestConfig autoTestConfig) {
    return calculateGrammar(spec.grammar, spec.inputFolder, autoTestConfig);
}