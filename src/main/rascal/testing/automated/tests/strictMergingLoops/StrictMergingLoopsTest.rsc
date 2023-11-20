module testing::automated::tests::strictMergingLoops::StrictMergingLoopsTest

import testing::automated::setup::runTest;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = forIn: For "(" Variable In Exp ")" Stmt
            | forIter: For "(" Exp Sep Exp Sep Exp ")" Stmt
            | "{" Stmt* "}"
            | Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

lexical For = @token="keyword" "for";
lexical In = @token="keyword.operator" "in";
lexical Sep = @token="entity.name.function" ";";
lexical Variable = @scope="variable" Id;

keyword KW = "for"|"in";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r];
      

void main() {
    runTest(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/strictMergingLoops|,
        autoTestConfig(testConfig=testConfig(overlapFinishRegex=true))
    );
}