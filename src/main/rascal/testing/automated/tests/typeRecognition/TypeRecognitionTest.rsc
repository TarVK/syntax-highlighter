module testing::automated::tests::typeRecognition::TypeRecognitionTest

import testing::automated::setup::runTest;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = Type Variable "=" Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

syntax Type = \type: TypeVariable
            | ar: Type "[]"
            | apply: Type "\<" {Type ","}+ "\>"
            | @token="primitive" number: "number"
            | @token="primitive" string: "string"
            | @token="primitive" boolean: "bool";

lexical Variable = @scope="variable" Id;
lexical TypeVariable = @scope="type" Id;

keyword KW = "bool"|"number"|"string";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = [\ \t\n\r]* !>> [\ \t\n\r%];
      
void main() {
    runTest(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/tests/typeRecognition|,
        autoTestConfig(addLookaheads=ConversionGrammar (ConversionGrammar conversionGrammar, Logger log) {
            return addGrammarLookaheads(conversionGrammar, log);
        })
    );
}