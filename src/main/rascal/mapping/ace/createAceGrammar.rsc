module mapping::ace::createAceGrammar

import Map;

import mapping::intermediate::PDAGrammar::PDAGrammar;
import mapping::common::stringifyOnigurumaRegex;
import mapping::ace::AceGrammar;
import mapping::ace::addRegexEndMatch;

@doc {
    Creates an ace grammar from the given PDA grammar

}
AceGrammar createAceGrammar(PDAGrammar grammar) {
    map[str, AceStateDefinition] states = ();
    
    <grammar, replacements> = replaceReservedSymbols(grammar);

    for(sym <- grammar.productions) {
        list[AceRule] outProds = [];

        symProds = grammar.productions[sym];
        for(prod <- symProds) {
            if(inclusion(s) := prod)
                outProds += includeRule(replaceReserved(s, replacements));
            else if(tokenProd(<regex, scopes>) := prod)
                outProds += tokenRule(
                    stringifyOnigurumaRegex(addRegexEndMatch(regex)), 
                    scopes
                );
            else if(pushProd(<regex, scopes>, push) := prod)
                outProds += pushRule(
                    stringifyOnigurumaRegex(addRegexEndMatch(regex)),
                    scopes,
                    replaceReserved(push, replacements)
                );
            else if(popProd(<regex, scopes>) := prod)
                outProds += nextRule(
                    stringifyOnigurumaRegex(addRegexEndMatch(regex)),
                    scopes,
                    "pop"
                );
        }

        states[sym] = outProds;
    }

    states["start"] = [includeRule(grammar.\start)];

    return states;
}

list[str] reservedSymbols = ["start"];
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

