module testing::automated::tests::closingNonDeterminism::ClosingNonDeterminismTest

import testing::automated::setup::runTest;
import specTransformations::GrammarTransformer;

syntax Program = Stmt*;
syntax Stmt = @token="bracket.1" "(" Exp ")"
            | Variable;

syntax Exp = bracketss: "[" Exp "]"
           | @token="bracket.2" ")"
           | var: Variable;

lexical Variable = @scope="variable" Id;

keyword KW = ;
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r];
      
void main() {
    runTest(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/closingNonDeterminism|
    );
}