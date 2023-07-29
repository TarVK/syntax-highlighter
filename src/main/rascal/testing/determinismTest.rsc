module testing::determinismTest

import IO;
import Grammar;
import ParseTree;
import ValueIO;

import Visualize;
import regex::PSNFA;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::RegexConversion;
import conversion::determinism::Determinism;

// syntax A = "okay" B
//          | "somethings" C;

// syntax B = "s"*;
// syntax C = "s"* !>> "s";

// syntax A = "something"
//          | "someth";


// import testing::grammars::Pico;
import testing::grammars::PicoImproved;

void main() {
    // loc pos = |project://syntax-highlighter/outputs/deterministicGrammar.bin|;
    loc inputPos = |project://syntax-highlighter/outputs/regexGrammar.bin|;
    inputGrammar = conversionGrammar = readBinaryValueFile(#ConversionGrammar,  inputPos);

    <dWarnings, conversionGrammar> = makeDeterministic(conversionGrammar);

    conversionGrammar = stripConvSources(conversionGrammar);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    visualize(insertPSNFADiagrams(<
        fromConversionGrammar(inputGrammar),
        stdGrammar,
        dWarnings
    >));
}