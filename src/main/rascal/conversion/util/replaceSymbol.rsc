module conversion::util::replaceSymbol

import ParseTree;

import conversion::conversionGrammar::ConversionGrammar;

@doc {
    Replaces all occurences of the given symbol in the grammar, and removes its definitions
}
ConversionGrammar replaceSymbol(Symbol replace, Symbol replaceBy, ConversionGrammar grammar) {
    substitutedProductions = { 
        <def, convProd(lDef, [
            ref(sym, scopes, sources) := part 
                ? getWithoutLabel(sym) == replace
                    ? ref(copyLabel(sym, replaceBy), scopes, sources)
                    : part
                : part
            | part <- parts
        ])>
        | <def, convProd(lDef, parts)> <- grammar.productions,
        def != replace // Remove the definition of replace, since it will no longer be referenced
    };
    grammar.productions = substitutedProductions;
    return grammar;
}

@doc {
    Renames the given symbol while keeping the language of the grammar in tact
}
ConversionGrammar renameSymbol(Symbol source, Symbol rename, ConversionGrammar grammar) {
    sourcePure = getWithoutLabel(source);
    grammar.productions += {
        <getWithoutLabel(rename), convProd(copyLabel(lDef, rename), parts)>
        | convProd(lDef, parts) <- grammar.productions[sourcePure]
    };

    return replaceSymbol(source, rename, grammar);
}