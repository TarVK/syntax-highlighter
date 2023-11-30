module testing::automated::experiments::overlapMerge::nonDeterminismFailed::OverlapMergeNonDeterminismFailedExperiment

import testing::automated::setup::runExperiment;
import TestConfig;

syntax Program1      = Exp1*;
syntax Exp1          = group:  "(" Exp1 ")"
                     | lambda: "(" {Variable ","}* ")" Lambda Exp1
                     | val:    Variable;

lexical Lambda       = @category="keyword" "=\>";
lexical Variable     = @category="variable" Id;
lexical Id           = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]);

layout Layout        = [\ \t\n\r]* !>> [\ \t\n\r%];
      
void main() {
    runExperiment(
        #Program1, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/overlapMerge/nonDeterminismFailed|
    );
}