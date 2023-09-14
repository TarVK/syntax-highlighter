module conversion::baseConversion::splitSequences

import Set;
import IO;

import conversion::util::makeLookahead;
import conversion::util::RegexCache;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::determinism::combineOverlap;
import conversion::shapeConversion::defineSequenceSymbol;
import conversion::shapeConversion::defineUnionSymbols;
import conversion::determinism::fixNullableRegexes;
import Warning;

@doc {
    Splits sequences into nested parts of one of the shape:
    ```
    A -> X B Y A
    A -> X B
    ```
}
WithWarnings[ConversionGrammar] splitSequences(ConversionGrammar grammar)
    = splitSequences(grammar, grammar.productions<0>);
WithWarnings[ConversionGrammar] splitSequences(ConversionGrammar grammar, set[Symbol] symbols) {
    list[Warning] warnings = [];

    println("start-split");
    while(size(symbols) > 0) {
        for(sym <- symbols) {
            <newWarnings, grammar> = splitSequences(sym, grammar);
            warnings += newWarnings;
        }

        <uWarnings, newUnionSyms, grammar> = defineUnionSymbols(grammar);
        grammar = deduplicateProductionsRespectingUnions(grammar);
        <cWarnings, newCombineSyms, grammar> = combineOverlapWithDefinedSymbols(grammar, newUnionSyms, 0);
        <fWarnings, grammar> = fixNullableRegexes(grammar, symbols);

        symbols = newUnionSyms + newCombineSyms;

        warnings += uWarnings + fWarnings;
    }
    return <warnings, grammar>;
}


WithWarnings[ConversionGrammar] splitSequences(Symbol sym, ConversionGrammar grammar) {
    list[Warning] warnings = [];

    // Skip alias symbols
    if({convProd(_, [symb(_, [])], _)} := grammar.productions[sym])
        return <warnings, grammar>;

    for(
        prod:convProd(_, parts, _) <- grammar.productions[sym],
        !hasAllowedShape(sym, parts)
    ) {
        println("Splitting sequence");
        <newWarnings, grammar> = splitSequence(prod, grammar);
        warnings += newWarnings;
    }

    return <warnings, grammar>;
}

bool hasAllowedShape(Symbol sym, list[ConvSymbol] parts) {
    if([] := parts) return true;
    if([regexp(_), symb(_, _)] := parts) return true;
    if([regexp(_), symb(_, _), regexp(_), symb(sym, [])] := parts) return true;
    if([regexp(_), symb(_, _), regexp(_), symb(label(sym, _), [])] := parts) return true;
    return false;
}

WithWarnings[ConversionGrammar] splitSequence(prod:convProd(lDef, _, _), ConversionGrammar grammar) {
    pureDef = getWithoutLabel(lDef);
    <warnings, splitProd, grammar> = getSplitProd(prod, grammar);
    grammar.productions -= {<pureDef, prod>};
    grammar.productions += {<pureDef, splitProd>};
    return <warnings, grammar>;
}

tuple[
    list[Warning] warnings,
    ConvProd prod,
    ConversionGrammar grammar
] getSplitProd(prod:convProd(lDef, parts, _), ConversionGrammar grammar) {
    pureDef = getWithoutLabel(lDef);
    if([regexp(s), *rest, regexp(e), symb(rec, [])] := parts, followAlias(rec, grammar) == pureDef) {
        endLA = makeLookahead(e);
        <warnings, symbol, grammar> = defineSequenceSymbol([*rest, regexp(endLA)], prod, grammar);
        return <
            warnings, 
            convProd(
                lDef, 
                [regexp(s), symb(symbol, []), regexp(e), symb(rec, [])], 
                {convProdSource(prod)}
            ), 
            grammar
        >;
    } else if([regexp(s), *rest] := parts) {
        <warnings, symbol, grammar> = defineSequenceSymbol(rest, prod, grammar);
        return <
            warnings, 
            convProd(
                lDef, 
                [regexp(s), symb(symbol, [])], 
                {convProdSource(prod)}
            ), 
            grammar
        >;
    }

    println("Error, every production should start with a regular expression");
    <warnings, symbol, grammar> = defineSequenceSymbol(parts, prod, grammar);
    return <
        warnings, 
        convProd(
            lDef, 
            [regexp(getCachedRegex(empty())), symb(symbol, [])],
            {convProdSource(prod)}
        ), 
        grammar
    >;
}