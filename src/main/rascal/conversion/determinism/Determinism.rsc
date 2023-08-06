module conversion::determinism::Determinism

import Relation;
import Set;
import Map;

import Warning;
import regex::PSNFA; 
import regex::Regex;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::determinism::improveAlternativesOverlap;
import conversion::determinism::improveExtensionOverlap;

data Warning = alternativesOverlap(Symbol source, ProdsOverlaps overlaps)
             | alternativesOverlapFix(Symbol source, ProdExtensions extensions)
             | extensionOverlap(ConvProd production, Regex regex, NFA[State] longerMatch)
             | extensionOverlapFix(ConvProd production, Regex regex, int length);

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
    rel[Symbol, ConvProd] newProds = {};
    for(<def, prod:convProd(lDef, parts, sources)> <- grammar.productions) {
        list[ConvSymbol] newParts = [];
        for(i <- [0..size(parts)]) {
            part = parts[i];
            if(regexp(re) := part) {
                follow = parts[i+1..];

                <newRe, nfaError, fixLength> = improveExtensionOverlap(re, follow, grammar, maxLookaheadLength);
                if(just(nfa) := nfaError)       warnings += extensionOverlap(prod, re, nfa);
                if(just(length) := fixLength)   warnings += extensionOverlapFix(prod, re, length);
                newParts += regexp(newRe);
            } else
                newParts += part;
        }

        newProds += <def, convProd(lDef, newParts, {convProdSource(prod)})>;
    }

    return <warnings, convGrammar(grammar.\start, newProds)>;
}