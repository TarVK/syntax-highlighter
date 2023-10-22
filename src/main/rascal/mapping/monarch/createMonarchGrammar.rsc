module mapping::monarch::createMonarchGrammar

import Map;

import mapping::intermediate::PDAGrammar::PDAGrammar;
import mapping::monarch::MonarchGrammar;
import mapping::common::HighlightGrammarData;
import mapping::common::stringifyOnigurumaRegex;

@doc {
    Creates a monarch grammar from the given PDA grammar, and additional highlighting grammar data

}
MonarchGrammar createMonarchGrammar(PDAGrammar grammar) {
    map[str, MonarchStateDefinition] tokenizer = ();

    // Root is a special reserved symbol name in monarch, so this symbol will be overwritten later if already used. This code only deals with teh very edge case of oot being used as a symbol name already
    str rootNameReplacement = "";
    
    <grammar, replacements> = replaceReservedSymbols(grammar);

    for(sym <- grammar.productions) {
        list[MonarchRule] outProds = [];

        symProds = grammar.productions[sym];
        for(prod <- symProds) {
            if(inclusion(s) := prod)
                outProds += includeRule(replaceReserved(s, replacements));
            else if(tokenProd(<regex, scopes>) := prod)
                outProds += tokenRule(
                    stringifyOnigurumaRegex(regex), 
                    [token(scope) | scope <- scopes]
                );
            else if(pushProd(<regex, scopes>, push) := prod)
                outProds += tokenRule(
                    stringifyOnigurumaRegex(regex),
                    [
                        stateChange(scope, "@<replaceReserved(push, replacements)>") 
                        | scope <- scopes
                    ]                    
                );
            else if(popProd(<regex, scopes>) := prod)
                outProds += tokenRule(
                    stringifyOnigurumaRegex(regex),
                    [
                        stateChange(scope, "@pop") 
                        | scope <- scopes
                    ]                    
                );
        }

        tokenizer[sym] = outProds;
    }

    tokenizer["root"] = [includeRule(grammar.\start)];

    return monarchGrammar(tokenizer);
}

list[str] reservedSymbols = ["root", "pop", "push", "popall"];
tuple[PDAGrammar, map[str, str]] replaceReservedSymbols(PDAGrammar grammar) {
    map[str, str] replacements = ();

    for(reserved <- reservedSymbols) {
        if(reserved in grammar.productions) {
            int id = 0;
            while("<reserved>_<id>" in grammar.productions) id += 1;
            reservedReplacement = "<reserved>_<id>";
            grammar.productions[reservedReplacement] = grammar.productions[root];
            grammar.productions = delete(grammar.productions, reserved);
            replacements[reserved] = reservedReplacement;

            if(grammar.\start == reserved) grammar.\start = reservedReplacement;
        }
    }

    return <grammar, replacements>;
}
str replaceReserved(str symbol, map[str, str] replacements) 
    = symbol in replacements ? replacements[symbol] : symbol;