module testing::automated::setup::viewGrammar

import ValueIO;

import Logging;
import Warning;
import TestConfig;
import convertGrammar;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import testing::automated::setup::calculateInputData;

@doc {
    Displays the grammar in debug tools
}
void viewGrammar(type[Tree] grammarTree, loc inputFolder)
    = viewGrammar(grammarTree, inputFolder, autoTestConfig());
void viewGrammar(type[Tree] grammarTree, loc inputFolder, AutomatedTestConfig autoTestConfig) {
    calculateGrammar(
        grammarTree, 
        inputFolder,
        autoTestConfig,
        {conversionGrammarOutput()}
    );
    generatePath = getGeneratePath(inputFolder);
    gd = readBinaryValueFile(#GrammarData, generatePath+"grammarData.bin");
    conversionGrammar = readBinaryValueFile(#ConversionGrammar, generatePath+"conversionGrammar.bin");

    visualizeGrammars(<
        fromConversionGrammar(toConversionGrammar(grammarTree, standardLogger(-1))<1>),
        fromConversionGrammar(conversionGrammar),
        gd
    >);
}