module conversion::util::Alias

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;

@doc {
    Follows any sequence of aliases until a defining symbol in the grammar is reached, and returns said symbol
}
Symbol followAlias(Symbol aliasSym, ConversionGrammar grammar) {
    aliasSym = getWithoutLabel(aliasSym);
    while({convProd(_, [ref(refSym, _, _)])} := grammar.productions[aliasSym]) aliasSym = getWithoutLabel(refSym);
    return aliasSym;
}

@doc { Checks whether the given symbol is an alias symbol }
bool isAlias(Symbol sym, ConversionGrammar grammar) 
    = {convProd(_, [ref(_, _, _)])} := grammar.productions[sym];
   
@doc {
    Follows all ref aliases in the given list of symbols
}
list[ConvSymbol] followPartsAliases(list[ConvSymbol] parts, ConversionGrammar grammar) {
    list[ConvSymbol] newParts = [];
    for(part <- parts) {
        if(ref(sym, scopes, sources) := part)
            newParts += ref(followAlias(sym, grammar), scopes, sources);
        else
            newParts += part;
    }
    return newParts;
}