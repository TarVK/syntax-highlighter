module testing::automated::tests::loopAmbiguity::LoopAmbiguityTest

import testing::automated::setup::runTest;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = forIn: For1 "(" Variable In Exp ")" Stmt
            | forIter: For2 "(" Exp Sep Exp Sep Exp ")" Stmt
            | "{" Stmt* "}"
            | Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

lexical For1 = @token="keyword.1" "for";
lexical For2 = @token="keyword.2" "for";
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
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/loopAmbiguity|
    );
}