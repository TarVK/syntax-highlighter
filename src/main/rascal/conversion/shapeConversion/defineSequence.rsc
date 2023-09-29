module conversion::shapeConversion::defineSequence

import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::util::meta::LabelTools;
import conversion::util::equality::ProdEquivalence;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::equality::ProdEquivalence;
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

    <sWarnings, sequences, recursions> = splitRecursion(parts, source);
    warnings += sWarnings;
    set[Symbol] sequenceSyms = {};
    for(sequence <- sequences) {
        indexParts = getEquivalenceSymbols(sequence);
        seqSym = convSeq(indexParts);
        sequenceSyms += seqSym;
        if(grammar.productions[seqSym] == {}) {
            grammar.productions += {<seqSym, convProd(relabelSymbol(seqSym, labels), sequence)>};
        } else if(labels != {} && {p:convProd(lSeqSym, _)} := grammar.productions[seqSym]) {
            if(label(t, _) := lSeqSym) labels += t;
            grammar.productions -= {<seqSym, p>};
            grammar.productions += {<seqSym, convProd(relabelSymbol(seqSym, labels), sequence)>};
        }
    }

    outSym = prefixes + recursions == {} && {sym} := sequenceSyms
        ? sym
        : simplify(unionRec(prefixes + sequenceSyms + recursions), grammar);
    return <warnings, outSym, grammar>;
}

@doc {
    Splits the given sequence into multiple parts if necessary, in order to prevent infinite recursions in symbol defining
    E.g. :
    "else" unionRec(Stmt|consSeq("else" Stmt X)) X
    =>
    {
        "else",
        unionRec(Stmt|consSeq("else" Stmt X)),
        X
    }
}
tuple[
    list[Warning] warnings,
    set[list[ConvSymbol]] sequences,
    set[Symbol] recursions
] splitRecursion(list[ConvSymbol] sequence, ConvProd source) {
    bool contains(Symbol sym) {
        switch(sym) {
            case convSeq(otherParts): {
                if(size(otherParts) == size(sequence)) {
                    samePattern = true;
                    for(i <- [0..size(sequence)], regexp(_) := sequence[i]) {
                        samePattern = equals(sequence[i], otherParts[i]);
                        if(!samePattern) break;
                    }
                    if(samePattern) return true;
                }
                
                return any(ref(refSym, _, _) <- otherParts, contains(refSym));
            }
            case unionRec(options, _): return any(option <- options, contains(option));
        }
        return false;
    }

    list[Warning] warnings = [];
    set[list[ConvSymbol]] outSequences = {};
    set[Symbol] recursions = {};

    list[ConvSymbol] prefix = [];
    for(part <- sequence) {
        if(ref(refSym, scopes, _) := part, contains(refSym)) {
            if(size(scopes) > 0) warnings += inapplicableScope(part, source);
            recursions += refSym;

            if(prefix != []) outSequences += prefix;
            prefix = [];
        } else {
            prefix += part;
        }
    }
    if(prefix != []) outSequences += prefix;

    return <warnings, outSequences, recursions>;
}

// TODO: remove if remains unused
// @doc {
//     Retrieves the parts that a given sequence symbol defines
// }
// Maybe[list[ConvSymbol]] retrieveSequence(Symbol sym, ConversionGrammar grammar) {
//     if(
//         convSeq(_) := sym,
//         {convProd(_, parts)} := grammar.productions[sym]
//     ) {
//         return just(parts);
//     }
//     return nothing();
// }