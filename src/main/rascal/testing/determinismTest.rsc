module testing::determinismTest

import IO;
import Grammar;
import ParseTree;
import ValueIO;

import Visualize;
import regex::PSNFA;
import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::RegexConversion;
import conversionGrammar::determinism::Determinism;

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
    <cWarnings, conversionGrammar> = toConversionGrammar(#A);
    conversionGrammar = convertToRegularExpressions(conversionGrammar);
    <dWarnings, conversionGrammar> = makeDeterministic(conversionGrammar);

    conversionGrammar = stripConvSources(conversionGrammar);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings + dWarnings;
    visualize(insertPSNFADiagrams(<
        grammar(#A),
        stdGrammar,
        warnings
    >));
}