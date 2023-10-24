module mapping::intermediate::PDAGrammar::toPDAGrammar

import util::Maybe;

import mapping::intermediate::PDAGrammar::PDAGrammar;
import mapping::intermediate::PDAGrammar::mergeScopes;
import mapping::intermediate::PDAGrammar::ScopeMerging;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import Logging;
import Warning;

@doc {
    Converts the given scope grammar to a PDA grammar defining the exact same tokenization function
}
WithWarnings[PDAGrammar] toPDAGrammar(ScopeGrammar grammar, ScopeMerger merge, Logger log) {
    log(Section(), "to pda grammar");

    log(Progress(), "merging scopes");
    <warnings, grammar> = mergeScopes(grammar, merge);
    PDAProductions prods = ();

    log(Progress(), "converting structure");
    set[str] takenNames = {sym | sym <- grammar.productions};
    map[tuple[str, ScopedRegex], str] closedNames = ();

    for(sym <- grammar.productions) {
        list[PDAProd] outProds = [];

        symProds = grammar.productions[sym];
        for(prod <- symProds) {
            if(ScopeProd::inclusion(r) := prod)
                outProds += PDAProd::inclusion(r, sources=prod.sources);
            else if(ScopeProd::tokenProd(r) := prod)
                outProds += PDAProd::tokenProd(r, sources=prod.sources);
            else if(scopeProd(beginR, <newState, scope>, endR) := prod) {
                key = <newState, endR>;
                str closingName;
                if(key in closedNames) closingName = closedNames[key];
                else {
                    // Find a unique name
                    int id = 0;
                    while("<newState>_<id>" in takenNames) id += 1;
                    closingName = "<newState>_<id>";
                    takenNames += closingName;

                    // Define the symbol+closing pair
                    closedNames[key] = closingName;
                    prods[closingName] = [
                        popProd(endR, sources=prod.sources), 
                        inclusion(newState, sources=prod.sources)
                    ];
                }

                outProds += pushProd(beginR, closingName, sources=prod.sources);
            }
        }

        prods[sym] = outProds;
    }

    return <warnings, PDAGrammar(grammar.\start, prods)>;
}