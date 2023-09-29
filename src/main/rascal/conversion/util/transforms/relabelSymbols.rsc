module conversion::util::transforms::relabelSymbols

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::transforms::replaceSymbol;

@doc {
    Renames the generated symbols to simple sort names
}
ConversionGrammar relabelGeneratedSymbols(ConversionGrammar grammar)
    = relabelGeneratedSymbolsWithMapping(grammar)<0>;
tuple[ConversionGrammar, SymMap] relabelGeneratedSymbolsWithMapping(ConversionGrammar grammar)
    = relabelSymbolsWithMapping(grammar, {
        sym 
        | sym <- grammar.productions<0>,
        unionRec(_, _) := sym || convSeq(_) := sym || closed(_, _) := sym
    }, str(Symbol sym) {
        switch(sym) {
            case unionRec(_, _): return "U";
            case convSeq(_): return "S";
            case closed(_, _): return "C";
        }
        return "G";
    });

@doc {
    Relabels the given set of symbols to simple sort names
}
ConversionGrammar relabelSymbols(ConversionGrammar grammar, set[Symbol] symbols)
    = relabelSymbolsWithMapping(grammar, symbols, str(Symbol){return "G";})<0>;
tuple[ConversionGrammar, SymMap] relabelSymbolsWithMapping(ConversionGrammar grammar, set[Symbol] symbols, str(Symbol) getPrefix) {
    int i=0;
    SymMap symMap = ();
    for(sym <- symbols) {
        prefixText = getPrefix(sym);
        Symbol rSym = sort("<prefixText><i>");
        while(grammar.productions[rSym] != {}){
            i += 1;
            rSym = sort("<prefixText><i>");
        }

        symMap[rSym] = sym;
        grammar = renameSymbol(sym, rSym, grammar);
        i += 1;
    }

    return <grammar, symMap>;
}

alias SymMap = map[Symbol, Symbol];