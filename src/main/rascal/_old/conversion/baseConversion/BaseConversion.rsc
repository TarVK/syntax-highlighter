module conversion::baseConversion::BaseConversion

import conversion::conversionGrammar::ConversionGrammar;
import conversion::baseConversion::carryClosingRegexes;
import conversion::baseConversion::makeSelfRecursive;
import conversion::baseConversion::splitSequences;
import Warning;

@doc {
    Makes sure that all productions have a shape that highlighting grammars can deal with.
    
    Assumes every production in the input grammar to either be an alias or start with a regular expression

    Ensures that every production in the output grammar is one of the shapes:
    ```
    A -> B
    A -> X A
    A -> X B Y A
    ```
}
WithWarnings[ConversionGrammar] makeBaseProductions(ConversionGrammar grammar) {
    grammar = carryClosingRegexes(grammar);
    grammar = makeSelfRecursive(grammar);

    <warnings, grammar> = splitSequences(grammar);
    warnings = [];

    return <warnings, grammar>;
}