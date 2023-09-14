module testing::conversionGrammarTest

import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;

import testing::grammars::SimpleScoped1;

void main() {
    <cWarnings, conversionGrammar> = toConversionGrammar(#Program);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings;
    visualizeGrammars(<
        conversionGrammar,
        stdGrammar,
        warnings
    >);
}