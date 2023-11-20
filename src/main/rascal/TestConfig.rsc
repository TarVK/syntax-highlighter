module TestConfig

import Logging;

@doc {
    Configuration for enabling and disabling features, that can be used for testing purposes
}
data TestConfig(
    // The final step that should be executed, to prematurely finish conversion
    PipelineStep lastPhase = complete(),
    // Whether to combine overlapping intial regular expressions
    bool combineOverlap = true,
    /* 
        Whether combining overlapping productions should finish in regular expressinos
        Consider productions:
        A -> x A y B z
        A -> x A w B z

        If enabled, prefix `x` and suffix `z` are detected.
        If disabled, prefix `x A` and suffix `B z` are detected.
        
        This means that when disabled, no lookahead regex is added to the remaining sequences. 
        E.g. enabled results in:
        A -> x unionRec(A|convSeq(y B />z/)|convSeq(w B />z/)) z
        disabled results in:         
        A -> x unionRec(A|convSeq(y)|convSeq(w)|B) z
    */
    bool overlapFinishRegex = false,
    // Whether to detect recursive convSequences generation, and relax them to no longer be recursive
    bool detectRecursion = true,
    // The log function to log progress
    Logger log = standardLogger()
) = testConfig();



data PipelineStep(int maxIterations = -1) 
    = regexConversion()
    | lookaheadAdding()
    | prefixConversion()
    | shapeConversion()
    | cleanup()
    | scopeGrammarCreation()
    | pdaGrammarCreation()
    | complete();