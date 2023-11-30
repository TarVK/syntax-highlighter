module testing::automated::experiments::\type::typeRecognition2::TypeRecognitionExperiment2

import Logging;
import conversion::conversionGrammar::ConversionGrammar;
import determinism::improvement::addGrammarLookaheads;

import testing::automated::setup::runExperiment;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = TypeWord TypeSuffix Variable "=" Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

syntax Type = TypeWord TypeSuffix;
syntax TypeSuffix = 
                  | ar: "[]" TypeSuffix
                  | apply: "\<" {Type ","}+ "\>" TypeSuffix;
syntax TypeWord = \type: TypeVariable
                | @categoryTerm="primitive" number: "number"
                | @categoryTerm="primitive" string: "string"
                | @categoryTerm="primitive" boolean: "bool";

lexical Variable = @category="variable" Id;
lexical TypeVariable = @category="type" Id;

keyword KW = "bool"|"number"|"string";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout  = [\ \t\n\r]* !>> [\ \t\n\r];
      
void main() {
    runExperiment(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/type/typeRecognition2|
    );
}