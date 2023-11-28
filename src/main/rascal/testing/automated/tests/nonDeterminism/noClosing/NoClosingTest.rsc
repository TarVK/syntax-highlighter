module testing::automated::tests::nonDeterminism::noClosing::NoClosingTest

import testing::automated::setup::runTest;

syntax NoClosings   = NoClosing*;
syntax NoClosing    = "(" NoClosing ")"
                    | @category="1" "s";

layout Layout        = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#NoClosing, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/nonDeterminism/noClosing|>;

test bool noClosingInput() = runTest(spec, "noClosing", false);
test bool noClosingError() = [] := getWarnings(spec);
