module testing::automated::tests::strictMergingIfElse::StrictMergingIfElseTest

import testing::automated::setup::runTest;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = iff: If "(" Exp ")" Stmt
            | iffElse: If "(" Exp ")" Stmt Else !>> [a-zA-Z0-9] Stmt
            | "{" Stmt* "}"
            | Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

lexical If = @token="keyword" "if";
lexical Else = @token="keyword" "else";
lexical Variable = @scope="variable" Id;

keyword KW = "if"|"else";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r];
      
void main() {
    runTest(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/strictMergingIfElse|,
        autoTestConfig(testConfig=testConfig(overlapFinishRegex=true))
    );
}