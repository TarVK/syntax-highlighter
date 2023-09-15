module Warning

import ParseTree;
import conversion::conversionGrammar::ConversionGrammar;

import Scope;

@Doc {
    A format for supplying warnings as output of the algorithm in case we cannot ensure a fully exact conversion
}
data Warning 
    // =========== Conversion grammar creation ===========
    /* Found a rascal condition that is not supported by the algorithm */
    = unsupportedCondition(Condition condition, Production inProd)
    /* Multiple tokens were found on a single rascal production, which is not supported because it doesn't define an order */
    | multipleTokens(set[ScopeList] tokens, Production inProd)
    /* Multiple scopes were found on a single rascal production, which is not supported because it doesn't define an order */
    | multipleScopes(set[ScopeList] scopes, Production inProd)
    // =========== Regex conversion ===========
    /* A modifier was supplied for something that can not be converted to a regular expression */
    | unresolvedModifier(ConvSymbol modifier, ConvProd production);

alias WithWarnings[&T] = tuple[list[Warning] warnings, &T result];

@doc {
    Checks whether the given warning is purely a warning (pointing at something that might have caused an error), or an error that indicates that the output is not guaranteed to adhere to spec.
}
bool isError(Warning warning) {
    // TODO:
    return true;
}