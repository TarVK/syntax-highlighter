module testing::automated::tests::nonDeterminism::extension::ExtensionTest

import testing::automated::setup::runTest;

syntax Extensions   = Extension*;
syntax Extension    = @category="1" "a"
                    | @category="2" "s"
                    | @category="3" "as";

layout Layout       = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#Extension, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/nonDeterminism/extension|>;

test bool extensionInput() {
    // It shouldn't be a test case nor negative test case, behavior is unspecified here, as it relies on iteration ordering of elements in set
    runTest(spec, "extension", false);
    return true;
}
test bool extensionError() = [extensionOverlap(_, _, _)] := getWarnings(spec);
