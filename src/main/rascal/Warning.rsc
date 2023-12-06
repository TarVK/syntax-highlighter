module Warning

import ParseTree;
import regex::RegexTypes;
import regex::PSNFATypes;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::prefixConversion::findNonProductiveRecursion;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
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
    | unresolvedModifier(ConvSymbol modifier, ConvProd forProd)
    // =========== Prefix conversion ===========
    /* A scope was provided for a non-terminal, but the symbol was involved in a left-recursive loop */
    | inapplicableScope(ConvSymbol sym, ConvProd forProd)
    // =========== Shape conversion ===========
    /* A scope was provided for a non-terminal, but the symbol had to merged with another symbol with different scopes */
    | incompatibleScopesForUnion(set[tuple[Symbol, ScopeList]], set[ConvProd] productions)
    /* We ararived at a cyclic path where no symbol has to be consumed, but can't safely solve such paths */
    | unresolvableLeftRecursiveLoop(set[EmptyPath] paths, ConvProd production)
    /* =========== Determinism checking ========== */
    /* We found overlap between a production and a regular expression that should close it */
    | closingOverlap(Regex alternativeExpression, Regex closingExpression, set[ConvProd] alternativeProductions, set[ConvProd] closingProductions, NFA[State] overlap)
    /* We found a regular expression that could both match a word and an extension of that same word */ 
    | extensionOverlap(Regex regex, set[ConvProd] productions, NFA[State] longerMatch)
    /* We found a regular expression that can match the same word with different scopes */
    | ambiguity(Regex regex, set[ConvProd] productions, NFA[State] path)
    /* =========== Scope grammar conversion =========== */
    /* We were not able to safely replace the subtraction by lookaheads or behinds */
    | unresolvableSubtraction(Regex regex, NFA[State] delta, ConvProd production)
    /* =========== PDA grammar conversion =========== */
    /* We are not able to deal with nested scopes when targetting PDAGrammars, found nesting */
    | disallowedNestedScopes(ScopeList nestedScopes, ScopeProd scopeProd)
    ;

alias WithWarnings[&T] = tuple[list[Warning] warnings, &T result];

@doc {
    Checks whether the given warning is purely a warning (pointing at something that might have caused an error), or an error that indicates that the output is not guaranteed to adhere to spec.
}
bool isError(Warning warning) {
    if(unresolvedModifier(_, _) := warning) return false;
    return true;
}