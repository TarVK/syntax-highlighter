module testing::automated::experiments::overlapMerge::determinismFailed::OverlapMergeDeterminismFailedExperiment

import testing::automated::setup::runExperiment;
import TestConfig;

syntax Program2      = Exp2*;
syntax Exp2          = group:  "(" Exp2 ")"
                     | lambda: ("(" {Variable ","}* ")") Lambda Exp2
                     | val:    Variable;

lexical Lambda       = @category="keyword" "=\>";
lexical Variable     = @category="variable" Id;
lexical Id           = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]);

layout Layout        = [\ \t\n\r]* !>> [\ \t\n\r];
      
void main() {
    runExperiment(
        #Program2, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/overlapMerge/determinismFailed|
    );
}