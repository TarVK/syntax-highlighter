module testing::automated::tests::subtractionRemoval::identifier4::SubtractionRemovalTest4

import testing::automated::setup::runTest;
import testing::automated::setup::runRobustnessTest;

syntax Identifier4 = @category="identifier" [a-z]+ \ "word"
                   | @category="keyword" "word";

GrammarSpec spec = <#Identifier4, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/subtractionRemoval/identifier4|>;

test bool somethingInput4() = runTest(spec, "something", false);
test bool awordInput4() = runTest(spec, "aword", false);
test bool wordsInput4() = runTest(spec, "words", true);
test bool wordInput4() = runTest(spec, "word", false);

test bool identifierErrors() = [] !:= getWarnings(spec);