module conversion::shapeConversion::defineSequenceSymbol

import ParseTree;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::customSymbols;
import conversion::shapeConversion::makePrefixedRightRecursive;
import Warning;

@doc {
    Defines a sequence symbol in the grammar. It makes sure that all created definitions start with a terminal symbol.
}
tuple[
    list[Warning] warnings,
    Symbol seqSymbol,
    ConversionGrammar grammar
] defineSequenceSymbol(
    list[ConvSymbol] parts, 
    set[SourceProd] sources, 
    ConversionGrammar grammar
) {
    list[Warning] warnings = [];
    set[Symbol] prefixes = {};

    while([symb(ref, scopes), *rest] := parts) {
        prefixes += getWithoutLabel(ref);
        if(size(scopes) > 0) warnings += inapplicableScope(scopes, p);
        parts = rest;
    }

    seqSym = convSeq(parts);
    if(size(grammar.productions[seqSym])==0) {
        partsProd = convProd(seqSym, parts, sources);
        grammar.productions += {<seqSym, partsProd>};
    }

    out = unionRec(prefixes, {seqSym});

    return <warnings, out, grammar>;
}