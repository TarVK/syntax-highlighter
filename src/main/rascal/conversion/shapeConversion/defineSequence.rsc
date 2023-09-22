module conversion::shapeConversion::defineSequence

import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::util::meta::LabelTools;
import conversion::util::equality::ProdEquivalence;
import conversion::conversionGrammar::CustomSymbols;
import Warning;

@doc {
    Adds a definition for the given sequence to the grammar, and adds the specified labels
}
tuple[
    list[Warning] warnings,
    Symbol symbol,
    ConversionGrammar grammar
] defineSequence(
    list[ConvSymbol] parts,  
    ConvProd source,
    ConversionGrammar grammar
) = defineSequence(parts, (just(l) := getLabel(source)) ? {l} : {}, grammar, source);
tuple[
    list[Warning] warnings,
    Symbol symbol,
    ConversionGrammar grammar
] defineSequence(
    list[ConvSymbol] parts, 
    set[str] labels, 
    ConversionGrammar grammar,
    ConvProd source
) {
    list[Warning] warnings = [];
    set[Symbol] prefixes = {};

    while([s:ref(refSym, scopes, _), *rest] := parts) {
        prefixes += followAlias(refSym, grammar);
        if(size(scopes) > 0) warnings += inapplicableScope(s, source);
        parts = rest;
    }

    if(parts == []) {
        outSym = simplify(unionRec(prefixes), grammar);
        return <warnings, outSym, grammar>;
    }

    indexParts = getEquivalenceSymbols(parts);
    seqSym = convSeq(indexParts);
    if(grammar.productions[seqSym] == {}) {
        grammar.productions += {<seqSym, convProd(relabelSymbol(seqSym, labels), parts)>};
    } else if(labels != {} && {p:convProd(lSeqSym, sParts)} := grammar.productions[seqSym]) {
        if(label(t, _) := lSeqSym) labels += t;
        grammar.productions -= {<seqSym, p>};
        grammar.productions += {<seqSym, convProd(relabelSymbol(seqSym, labels), parts)>};
    }

    outSym = prefixes == {} 
        ? simplify(seqSym, grammar)
        : simplify(unionRec(prefixes + {seqSym}), grammar);

    return <warnings, outSym, grammar>;
}