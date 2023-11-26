module testing::automated::tests::overlapMergeDeterminism::OverlapMergeDeterminismTest

import testing::automated::setup::runTest;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | lambda: ("(" {Variable ","}* ")") Lambda "{" Stmt* "}"
           | string: Str
           | var: Variable;

lexical Str =  @scope="string.template" "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "("
             | @token="constant.character.escape" escape: "\\"![]
             | @scope="meta.embedded.line" embedded: "$(" Layout Exp Layout ")";
lexical Lambda = @token="keyword" "=\>";
lexical Variable = @scope="variable" Id;

keyword KW = ;
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = [\ \t\n\r]* !>> [\ \t\n\r%];
      
void main() {
    runTest(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/overlapMergeDeterminism|
    );
}