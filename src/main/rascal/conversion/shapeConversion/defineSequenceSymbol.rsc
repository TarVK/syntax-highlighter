module conversion::shapeConversion::defineSequenceSymbol

import ParseTree;
import Set;
import String;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::customSymbols;
import conversion::shapeConversion::makePrefixedRightRecursive;
import conversion::util::RegexCache;
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
    ConvProd source, 
    ConversionGrammar grammar
) 
    = defineSequenceSymbol(parts, {convProdSource(source)}, grammar, getLabel(source));
tuple[
    list[Warning] warnings,
    Symbol seqSymbol,
    ConversionGrammar grammar
] defineSequenceSymbol(
    list[ConvSymbol] parts, 
    set[SourceProd] sources, 
    ConversionGrammar grammar,
    Maybe[str] prodLabel
) {
    list[Warning] warnings = [];
    set[Symbol] prefixes = {};

    while([symb(ref, scopes), *rest] := parts) {
        prefixes += getWithoutLabel(ref);
        if(size(scopes) > 0) warnings += inapplicableScope(scopes, p);
        parts = rest;
    }

    specParts = removeRegexCache(parts); // Remove irrelevant data
    seqSym = convSeq(specParts);
    if(size(grammar.productions[seqSym])==0) {
        lSeqSym = just(text) := prodLabel ? label(text, seqSym) : seqSym;
        partsProd = convProd(lSeqSym, parts, sources);

        grammar.productions += {<seqSym, partsProd>};
    } else if(just(text) := prodLabel && {p:convProd(lSeqSym, parts, sources)} := grammar.productions[seqSym]) {
        // Update the label to include the new label
        Maybe[str] newTextM = nothing();
        if(label(curText, _) := lSeqSym) {
            if(!contains(curText, text)) 
                newTextM = just("<curText>,<text>");
        } else newTextM = just("<text>");

        if(just(newText) := newTextM) {
            grammar.productions -= {<seqSym, p>};
            grammar.productions += {<seqSym, convProd(label(newText, seqSym), parts, sources)>};
        }
    }

    out = unionRec(prefixes + {seqSym});

    return <warnings, out, grammar>;
}