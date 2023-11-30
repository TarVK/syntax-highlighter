module testing::automated::tests::nonDeterminism::noExtension::NoExtensionTest

import testing::automated::setup::runTest;


syntax NoExtensions   = NoExtension*;
syntax NoExtension    = @category="1" "a" !>> "s"
                      | @category="2" "s"
                      | @category="3" "as";

layout Layout         = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#NoExtension, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/nonDeterminism/noExtension|>;

test bool noExtensionInput() = runTest(spec, "noExtension", false);
test bool noExtensionError() = [] := getWarnings(spec);
