module testing::automated::tests::nonDeterminism::closing::ClosingTest

import testing::automated::setup::runTest;
import Warning;


syntax Closings     = Closing*;
syntax Closing      = "(" Closing ")"
                    | @category="1" ")";
                    
layout Layout       = [\ \t\n\r]* !>> [\ \t\n\r];


GrammarSpec spec = <#Closings, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/nonDeterminism/closing|>;

test bool closingInput() = runTest(spec, "closing", true);
test bool closingError() = [closingOverlap(_, _, _, _, _)] := getWarnings(spec);
