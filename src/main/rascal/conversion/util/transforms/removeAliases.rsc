module conversion::util::transforms::removeAliases

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::util::transforms::replaceSymbol;

@doc {
    Removes aliases from the grammar by following them to a definition
}
ConversionGrammar removeAliases(ConversionGrammar grammar) {
    symbols = grammar.productions<0>;
    aliases = {sym | sym <- symbols, isAlias(sym, grammar)};
    for(aliasSym <- aliases)
        grammar = replaceSymbol(aliasSym, followAlias(aliasSym, grammar), grammar);
    return grammar;
}
