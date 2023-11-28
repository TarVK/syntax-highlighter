module testing::automated::tests::subtractionRemoval::identifier2::SubtractionRemovalTest2

import testing::automated::setup::runTest;
import testing::automated::setup::runRobustnessTest;

syntax Identifier2 = @category="identifier" [a-z] !<< [a-z]+ \ "word" !>> [a-z] 
                   | @category="keyword" "word";

GrammarSpec spec = <#Identifier2, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/subtractionRemoval/identifier2|>;

test bool somethingInput2() = runTest(spec, "something", false);
test bool awordInput2() = runTest(spec, "aword", false);
test bool wordsInput2() = runTest(spec, "words", false);
test bool wordInput2() = runTest(spec, "word", false);