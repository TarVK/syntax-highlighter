module testing::automated::experiments::overlapMergeNonDeterminismFailed::OverlapMergeNonDeterminismFailedExperiment

import testing::automated::setup::runExperiment;
import TestConfig;

syntax Program = Stmt*;
syntax Stmt = Exp ";";

syntax Exp = bracketss: "(" Exp ")"
           | lambda: "(" {Variable ","}* ")" Lambda "{" Stmt* "}"
           | string: Str
           | var: Variable;

lexical Str =  @category="string.template" "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @categoryTerm="constant.character.escape" escape: "\\"![]
             | @category="meta.embedded.line" embedded: "${" Layout Exp Layout "}";
lexical Lambda = @categoryTerm="keyword" "=\>";
lexical Variable = @category="variable" Id;

keyword KW = ;
lexical Id = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]) \ KW;

layout Layout = [\ \t\n\r]* !>> [\ \t\n\r%];
      
void main() {
    runExperiment(
        #Program, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/overlapMergeNonDeterminismFailed|
    );
}