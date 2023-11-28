module testing::manual::regexConversionTest

import Logging;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;

import specTransformations::tokenAugmenters::addKeywordTokens;
import specTransformations::tokenAugmenters::addOperatorTokens;
import specTransformations::transformerUnion;
import specTransformations::productionRetrievers::allProductions;
import specTransformations::productionRetrievers::exceptKeywordsProductions;

// import testing::grammars::SimpleScoped1;
// import testing::grammars::SimpleLanguage;

syntax Program = "a" B "c"
               | "b" B "c"
               | "a" B "d"
               | "b" B "d"
               | C;
syntax B = "(" B ")"
         |;
syntax C = @categoryTerm="o" "(" C
         | @categoryTerm="o" "[" C
         | @categoryTerm="c" C ")"
         | @categoryTerm="c" C "]" >> ")"
         | "{" D;
syntax D = "}";

void main() {
    log = standardLogger();
    <cWarnings, conversionGrammar> = toConversionGrammar(#Program, log);

    // addGrammarTokens = transformerUnion([
    //     addKeywordTokens(exceptKeywordsProductions(allProductions)),
    //     addOperatorTokens(exceptKeywordsProductions(allProductions))
    // ]);
    // conversionGrammar = addGrammarTokens(conversionGrammar, log);

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