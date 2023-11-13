module testing::manual::conversionGrammarTest

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;

import testing::grammars::SimpleScoped1;

void main() {
    log = standardLogger();
    <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings;
    visualizeGrammars(<
        conversionGrammar,
        stdGrammar,
        warnings
    >);
}