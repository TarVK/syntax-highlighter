module testing::automated::tests::nonDeterminism::ambiguity::AmbiguityTest

import testing::automated::setup::runTest;


syntax Ambiguity    = AmbiguityAlt*;
syntax AmbiguityAlt = KW1 "!" | KW2 "?";
lexical KW1         = @category="1"  "s";
lexical KW2         = @category="2"  "s";

layout Layout       = [\ \t\n\r]* !>> [\ \t\n\r];

GrammarSpec spec = <#Ambiguity, |project://syntax-highlighter/src/main/rascal/testing/automated/tests/nonDeterminism/ambiguity|>;

test bool ambiguityInput() = runTest(spec, "ambiguity", true);
test bool ambiguityError() = [ambiguity(_, _, _)] := getWarnings(spec);