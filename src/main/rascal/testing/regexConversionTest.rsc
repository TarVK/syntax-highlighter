module testing::regexConversionTest

import Logging;
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
    log = standardLogger();
    <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);
    inputGrammar = fromConversionGrammar(conversionGrammar);
    <rWarnings, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
    stdGrammar = fromConversionGrammar(conversionGrammar);

    warnings = cWarnings + rWarnings;
    visualizeGrammars(<
        inputGrammar,
        stdGrammar,
        warnings
    >);
}