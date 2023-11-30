module testing::automated::tests::merging::disabled::NoMergingTest

import testing::automated::setup::runTest;
import testing::automated::setup::runRobustnessTest;
import TestConfig;

syntax Merges = Merge*;
syntax Merge  = A SB D
              | A SC D;
syntax SB     = "(" SB ")" | B;
syntax SC     = "(" SC ")" | C;
lexical A     = @category="1"  "a";
lexical B     = @category="2"  "b";
lexical C     = @category="3"  "c";
lexical D     = @category="4"  "d";
      
layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#Merges, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/merging/disabled|>;
AutomatedTestConfig config = autoTestConfig(testConfig=testConfig(combineOverlap=false));

test bool mergeAlt1Input() {
    runTest(spec, "mergeAlt1", false, config);
    return true;
}
test bool mergeAlt2Input() {
    runTest(spec, "mergeAlt2", true, config);
    return true;
}
test bool mergeAlt1GroupedInput() {
    runTest(spec, "mergeAlt1Grouped", false, config);
    return true;
}
test bool mergeAlt2GroupedInput() {
    runTest(spec, "mergeAlt2Grouped", true, config);
    return true;
}
test bool mergeAltBothInput() = runTest(spec, "mergeAltBoth", true, config);
test bool mergeAltGroupedBothInput() = runTest(spec, "mergeAltGroupedBoth", true, config);