module testing::automated::tests::extensionNonDeterminism::ExtensionNonDeterminismTest

import testing::automated::setup::runTest;
import specTransformations::GrammarTransformer;

syntax Program = Stmt*;
syntax Stmt = forIn: For "(" Variable In Exp ")" Stmt
            | "{" Stmt* "}"
            | Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

lexical For = @token="keyword" "for";
lexical In = @token="keyword.operator" "in";
lexical Variable = @scope="variable" Id;

keyword KW = "for"|"in";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r];
      
void main() {
    runTest(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/extensionNonDeterminism|,
        autoTestConfig(addLookaheads=transformerIdentity)
    );
}