module testing::automated::tests::merging::MergingTest

import testing::automated::setup::runTest;
import testing::automated::setup::runRobustnessTest;


syntax Merge  = A SB D
              | A SC D;
syntax SB     = "(" SB ")" | B;
syntax SC     = "(" SC ")" | C;
lexical A     = @category="1"  "a";
lexical B     = @category="2"  "b";
lexical C     = @category="3"  "c";
lexical D     = @category="4"  "d";
      
layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#Merge, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/merging|>;

test bool mergeAlt1Input() = runTest(spec, "mergeAlt1", false);
test bool mergeAlt2Input() = runTest(spec, "mergeAlt2", false);
test bool mergeAlt1GropuedInput() = runTest(spec, "mergeAlt1Grouped", false);
test bool mergeAlt2GropuedInput() = runTest(spec, "mergeAlt2Grouped", false);