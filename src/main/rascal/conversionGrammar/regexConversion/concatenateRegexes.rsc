module conversionGrammar::regexConversion::concatenateRegexes

import conversionGrammar::ConversionGrammar;

@doc {
    Tries to apply the union rule:
    ```
    A -> x X y          
    A -> x Y y          
    ```
    => {Union}
    ```
    A -> x (X | Y) y
    ```

    This is done exhasutively for this production set.
}
tuple[ConversionGrammar, set[ConvProd]] concatenateRegexes(ConversionGrammar grammar, set[ConvProd] productions) 
    = unionRegexes(grammar, productions, 0);

@doc {
    Tries to apply the union rule:
    ```
    A -> x X y          
    A -> x Y y          
    ```
    => {Union}
    ```
    A -> x (X | Y) y
    ```

    This is done exhasutively for this production set.
    Assumes the symbols up to and excluding startIndex to be identical between all productions
}
tuple[ConversionGrammar, set[ConvProd]] unionRegexes(ConversionGrammar grammar, set[ConvProd] productions, int startIndex) {
}