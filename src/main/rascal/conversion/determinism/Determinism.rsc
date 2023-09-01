module conversion::determinism::Determinism

import Relation;
import Set;
import Map;

import Warning;
import regex::PSNFA; 
import regex::Regex;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::determinism::combineOverlap;
import conversion::determinism::checkDeterminism;
import conversion::determinism::improveAlternativesOverlap;
import conversion::determinism::improveExtensionOverlap;
import conversion::determinism::fixNullableRegexes;
import conversion::determinism::expandFollow;

data Warning = alternativesOverlap(Symbol source, ProdsOverlaps overlaps)
             | alternativesOverlapFix(Symbol source, ProdExtensions extensions)
             | extensionOverlap(ConvProd production, Regex regex, NFA[State] longerMatch)
             | extensionOverlapFix(ConvProd production, Regex regex, int length);

@doc {
    Attempts to make the given grammar deterministic with respect to the regular expressions, while keeping the language equivalent

    The maxLookaheadLength specifies how many productions may be expanded into a lookahead to improve determinism when needed, at the expense of "responsiveness" of the grammar (The user will have to type more before previously typed words are finally highlighted). 
}
WithWarnings[ConversionGrammar] makeDeterministic(
    ConversionGrammar grammar, 
    ConversionGrammar exactGrammar
) = makeDeterministic(grammar, exactGrammar, 1);
WithWarnings[ConversionGrammar] makeDeterministic(
    ConversionGrammar grammar, 
    ConversionGrammar exactGrammar,
    int maxLookaheadLength
) {
    list[Warning] warnings = [];
    
    <nWarnings, grammar> = fixNullableRegexes(grammar);
    warnings += nWarnings;

    grammar = fixOverlap(grammar, exactGrammar, maxLookaheadLength);

    <cWarnings, grammar> = combineOverlap(grammar, exactGrammar, maxLookaheadLength);
    warnings += cWarnings;

    warnings += checkDeterminism(grammar);

    return <warnings, grammar>;
}