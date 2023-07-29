module conversionGrammar::determinism::Determinism

import Relation;
import Set;
import Map;

import Warning;
import regex::PSNFA;
import conversionGrammar::ConversionGrammar;
import conversionGrammar::determinism::improveAlternativesOverlap;
import conversionGrammar::determinism::checkExtensionOverlap;

data Warning = alternativesOverlap(Symbol source, ProdsOverlaps overlaps)
             | alternativesOverlapFix(Symbol source, ProdExtensions extensions)
             | extensionOverlap(ConvProd production, NFA[State] longerMatch);

@doc {
    Attempts to make the given grammar deterministic with respect to the regular expressions, while keeping the language equivalent

    The maxLookaheadLength specifies how many productions may be expanded into a lookahead to improve determinism when needed, at the expense of "responsiveness" of the grammar (The user will have to type more before previously typed words are finally highlighted). 
}
WithWarnings[ConversionGrammar] makeDeterministic(ConversionGrammar grammar) = makeDeterministic(grammar, 3);
WithWarnings[ConversionGrammar] makeDeterministic(ConversionGrammar grammar, int maxLookaheadLength) {
    list[Warning] warnings = [];

    // Check for alternative overlap
    productions = index(grammar.productions);
    for(sym <- productions<0>) {
        symProds = productions[sym];
        <newSymProds, overlaps, extensions> = improveAlternativesOverlap(symProds, grammar, maxLookaheadLength);
        productions[sym] = newSymProds;

        if(size(overlaps)>0) warnings += alternativesOverlap(sym, overlaps);
        if(size(extensions)>0) warnings += alternativesOverlapFix(sym, extensions);
    }
    grammar = convGrammar(grammar.\start, toRel(productions));

    // Check for regex extension self-overlap
    for(<_, prod:convProd(_, [regexp(re), *_], _)> <- grammar.productions) {
        if(just(nfa) := checkExtensionOverlap(re)) {
            warnings += extensionOverlap(prod, nfa);
        }
    }

    return <warnings, grammar>;
}