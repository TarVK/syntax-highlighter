module testing::automated::experiments::overlapMerge::determinism::OverlapMergeDeterminismExperiment

import testing::automated::setup::runExperiment;
import TestConfig;

syntax Program2B     = Exp2B*;
syntax Exp2B         = group:                     "(" Exp2B ")"
                     | lambda:                    ("(" {Variable ","}* ")") Lambda Exp2B
                     | @category="string" string: "\"" Char* "\"" 
                     | var:                       Variable;

lexical Char         = char:                                         ![\\\"$]
                     | dollarChar:                                   "$" !>> "("
                     | @category="constant.character.escape" escape: "\\"![]
                     | @category="meta.embedded.line" embedded:      "$(" Layout Exp2B Layout ")";
lexical Lambda       = @category="keyword" "=\>";
lexical Variable     = @category="variable" Id;
lexical Id           = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]);

layout Layout        = [\ \t\n\r]* !>> [\ \t\n\r];
      
void main() {
    runExperiment(
        #Program2B, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/overlapMerge/determinism|
    );
}