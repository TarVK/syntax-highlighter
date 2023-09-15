module testing::regexConversionTest

import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;

// import testing::grammars::SimpleScoped1;

syntax Program = "a" B "c"
               | "b" B "c"
               | "a" B "d"
               | "b" B "d"
               | C;
syntax B = "(" B ")"
         |;
syntax C = @token="o" "(" C
         | @token="o" "[" C
         | @token="c" C ")"
         | @token="c" C "]" >> ")"
         | "{" D;
syntax D = "}";

void main() {
    <cWarnings, conversionGrammar> = toConversionGrammar(#Program);
    inputGrammar = fromConversionGrammar(conversionGrammar);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings + rWarnings;
    visualizeGrammars(<
        inputGrammar,
        stdGrammar,
        warnings
    >);
}