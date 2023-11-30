module testing::automated::experiments::exponentialMergingFailed::ExponentialMergingExperiment

import testing::automated::setup::viewGrammar;

syntax Merge3 = A Merge3
              | A Merge3 B Merge3
              | C Merge3
              | C Merge3 D Merge3
              | E Merge3
              | E Merge3 F Merge3
              | G;
lexical A     = @category="1"  "a";
lexical B     = @category="2"  "b";
lexical C     = @category="3"  "c";
lexical D     = @category="4"  "d";
lexical E     = @category="5"  "e";
lexical F     = @category="6"  "f";
lexical G     = @category="7"  "g";
      
void main() {
    viewGrammar(
        #Merge3, 
        |project://syntax-highlighter/src/main/rascal/testing/automated/experiments/exponentialMergingFailed|
    );
}