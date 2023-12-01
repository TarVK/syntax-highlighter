module testing::automated::experiments::\type::typeRecognition::TypeRecognitionExperiment

import Logging;
import conversion::conversionGrammar::ConversionGrammar;
import determinism::improvement::addGrammarLookaheads;
import testing::automated::setup::viewGrammar;

import testing::automated::setup::runExperiment;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = Type Variable "=" Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | var: Variable;

syntax Type = \type: TypeVariable
            | ar: Type "[]"
            | apply: Type "\<" {Type ","}+ "\>"
            | @categoryTerm="primitive" number: "number"
            | @categoryTerm="primitive" string: "string"
            | @categoryTerm="primitive" boolean: "bool";

lexical Variable = @category="variable" Id;
lexical TypeVariable = @category="type" Id;

keyword KW = "bool"|"number"|"string";
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout        = [\ \t]* !>> [\ \t\n\r]
                     | [\ \t]*[\n\r][\ \t\n\r]* !>> [\ \t\n\r];
                     
      
void main() {
    path = |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/type/typeRecognition|;
    conf = autoTestConfig(addLookaheads=ConversionGrammar (ConversionGrammar conversionGrammar, Logger log) {
        return addGrammarLookaheads(conversionGrammar, 1, 2, log);
    });

    runExperiment(#Program, path, conf);
    // viewGrammar(#Program, path, conf);
}