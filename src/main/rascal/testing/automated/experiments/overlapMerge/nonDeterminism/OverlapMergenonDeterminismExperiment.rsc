module testing::automated::experiments::overlapMerge::nonDeterminism::OverlapMergenonDeterminismExperiment

import testing::automated::setup::runExperiment;
import TestConfig;


import Logging;
import conversion::conversionGrammar::ConversionGrammar;
import determinism::improvement::addDynamicGrammarLookaheads;
import determinism::check::checkDeterminism;
import regex::Regex;


syntax Program1B     = Exp1B*;
syntax Exp1B         = group:                     "(" Exp1B ")"
                     | lambda:                    "(" {Variable ","}* ")" Lambda Exp1B
                     | @category="string" string: "\"" Char* "\"" 
                     | var:                       Variable;

lexical Char         = char:                                         ![\\\"$]
                     | dollarChar:                                   "$" !>> "("
                     | @category="constant.character.escape" escape: "\\"![]
                     | @category="meta.embedded.line" embedded:      "$(" Layout Exp1B Layout ")";
lexical Lambda       = @category="keyword" "=\>";
lexical Variable     = @category="variable" Id;
lexical Id           = ([a-z0-9] !<< [a-z][a-z0-9]* !>> [a-z0-9]);

layout Layout        = [\ \t\n\r]* !>> [\ \t\n\r];

void main() {
    runExperiment(
        #Program1B, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/overlapMerge/nonDeterminism|
    );
}