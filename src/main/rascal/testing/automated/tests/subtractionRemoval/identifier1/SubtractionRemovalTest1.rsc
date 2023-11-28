module testing::automated::tests::subtractionRemoval::identifier1::SubtractionRemovalTest1

import testing::automated::setup::runTest;
import testing::automated::setup::runRobustnessTest;

syntax Identifier1 = @category="identifier" [a-z] !<< [a-z]+ !>> [a-z] \ "word"
                   | @category="keyword" "word";

GrammarSpec spec = <#Identifier1, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/subtractionRemoval/identifier1|>;

test bool somethingInput1() = runTest(spec, "something", false);
test bool awordInput1() = runTest(spec, "aword", false);
test bool wordsInput1() = runTest(spec, "words", false);
test bool wordInput1() = runTest(spec, "word", false);