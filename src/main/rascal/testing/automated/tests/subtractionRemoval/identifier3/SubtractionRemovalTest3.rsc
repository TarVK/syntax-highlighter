module testing::automated::tests::subtractionRemoval::identifier3::SubtractionRemovalTest3

import testing::automated::setup::runTest;
import testing::automated::setup::runRobustnessTest;

syntax Identifier3 = @category="identifier" [a-z] !<< [a-z]+ \ "word"
                   | @category="keyword" "word";

GrammarSpec spec = <#Identifier3, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/subtractionRemoval/identifier3|>;

test bool somethingInput3() = runTest(spec, "something", false);
test bool awordInput3() = runTest(spec, "aword", false);
test bool wordsInput3() = runTest(spec, "words", false);
test bool wordInput3() = runTest(spec, "word", false);

test bool identifierErrors() = [] := getWarnings(spec);