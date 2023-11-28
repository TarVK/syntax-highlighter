module testing::automated::tests::nonDeterminism::noAmbiguity::NoAmbiguityTest

import testing::automated::setup::runTest;


syntax NoAmbiguity    = NoAmbiguityAlt*;
lexical NoAmbiguityAlt = KW1 "!" | KW2 "?";
lexical KW1           = @category="1" "s";
lexical KW2           = @category="2" "s";

layout Layout        = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#NoAmbiguity, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/nonDeterminism/noAmbiguity|>;

test bool noAmbiguityInput() = runTest(spec, "noAmbiguity", false);
test bool noAmbiguityError() = [] := getWarnings(spec);