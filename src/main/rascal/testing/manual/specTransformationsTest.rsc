module testing::manual::specTransformationsTest

import Grammar;

import Logging;
import testing::util::visualizeGrammars;
import specTransformations::addWordBorders;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import specTransformations::tokenAugmenters::addKeywordTokens;
import specTransformations::tokenAugmenters::addOperatorTokens;
import specTransformations::transformerUnion;
import specTransformations::productionRetrievers::allProductions;
import specTransformations::productionRetrievers::exceptKeywordsProductions;

import testing::grammars::SimpleScoped3;

void main() {
    log = standardLogger();
    inputGrammar = grammar(#Program);
    inputGrammar = addWordBorders(
        inputGrammar, 
        [range(48, 57), range(65, 90), range(97, 122)] // 0-9A-Za-z
    );
    <cWarnings, conversionGrammar> = toConversionGrammar(inputGrammar, log);

    addGrammarTokens = transformerUnion([
        addKeywordTokens(exceptKeywordsProductions(allProductions)),
        addOperatorTokens(exceptKeywordsProductions(allProductions))
    ]);
    conversionGrammar = addGrammarTokens(conversionGrammar, log);
    log(Section(), "finished");

    warnings = cWarnings;
    visualizeGrammars(<
        inputGrammar,
        fromConversionGrammar(conversionGrammar),
        warnings
    >);
}