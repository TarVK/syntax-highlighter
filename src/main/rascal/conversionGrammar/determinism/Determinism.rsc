module conversionGrammar::determinism::Determinism

import Relation;
import Set;

import Warning;
import regex::PSNFA;
import conversionGrammar::ConversionGrammar;
import conversionGrammar::determinism::checkAlternativesOverlap;
import conversionGrammar::determinism::checkExtensionOverlap;

data Warning = alternativesOverlap(Symbol source, ProdsOverlaps overlaps)
             | extensionOverlap(ConvProd production, NFA[State] longerMatch);

@doc {
    Attempts to make the given grammar deterministic with respect to the regular expressions, while keeping the language equivalent
}
WithWarnings[ConversionGrammar] makeDeterministic(ConversionGrammar grammar) {
    list[Warning] warnings = [];

    // Check for alternative overlap
    productions = index(grammar.productions);
    for(sym <- productions<0>) {
        symProds = productions[sym];
        overlaps = checkAlternativesOverlap(symProds);
        if(size(overlaps)>0) {
            warnings += alternativesOverlap(sym, overlaps);
        }
    }

    // Check for regex extension self-overlap
    for(<_, prod:convProd(_, [regexp(re), *_], _)> <- grammar.productions) {
        if(just(nfa) := checkExtensionOverlap(re)) {
            warnings += extensionOverlap(prod, nfa);
        }
    }

    return <warnings, grammar>;
}