module testing::automated::tests::strictMerging::strict::StrictMergingTest

import testing::automated::setup::runTest;
import testing::automated::setup::runRobustnessTest;
import TestConfig;


syntax Merge2 = A Merge2
              | A Merge2 B Merge2
              | C;
lexical A     = @category="1"  "a";
lexical B     = @category="2"  "b";
lexical C     = @category="3"  "c";
      
layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#Merge2, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/strictMerging/strict|>;
AutomatedTestConfig config = autoTestConfig(testConfig=testConfig(overlapFinishRegex=true));

test bool noSuffixInput() = runTest(spec, "noSuffix", false, config);
test bool suffix1Input() = runTest(spec, "1suffix", false, config);
test bool suffix2Input() = runTest(spec, "2suffix", false, config);
test bool suffix2SeqInput() = runTest(spec, "2suffixSeq", false, config);

test bool onlySuffixInput() = runRobustnessTest(spec, "onlySuffix", [[], [], ["3"]], config);
test bool doubleSuffixInput() = runRobustnessTest(spec, "doubleSuffix", [["1"],[],["3"],[],["2"],[],["3"],[],[],[],["3"]], config);
test bool tripleSuffixInput() = runRobustnessTest(spec, "tripleSuffix", [["1"],[],["3"],[],["1"],[],["3"],[],["2"],[],["3"],[],["2"],[],["3"],[],["2"],[],["3"]], config);