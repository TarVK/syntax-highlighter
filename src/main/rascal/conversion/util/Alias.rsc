module conversion::util::Alias

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::meta::LabelTools;
import conversion::util::BaseNFA;

@doc {
    Follows any sequence of aliases until a defining symbol in the grammar is reached, and returns said symbol
}
Symbol followAlias(Symbol aliasSym, ConversionGrammar grammar) {
    aliasSym = getWithoutLabel(aliasSym);
    while(true) {
        if({convProd(_, [ref(refSym, _, _)])} := grammar.productions[aliasSym]) 
            aliasSym = getWithoutLabel(refSym);
        else if(
            unionRec(syms, n) := aliasSym, 
            n != emptyNFA,
            {convProd(_, [ref(unionRec(newSyms, _), _, _)])} := grammar.productions[unionRec(syms, emptyNFA)]
        )
            aliasSym = unionRec(newSyms, n);
        else break;
    }
    return aliasSym;
}

@doc { Checks whether the given symbol is an alias symbol }
bool isAlias(Symbol sym, ConversionGrammar grammar) 
    = {convProd(_, [ref(_, _, _)])} := grammar.productions[sym]
    || (unionRec(syms, n) := sym && n != emptyNFA && isAlias(unionRec(syms, emptyNFA), grammar));
   
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