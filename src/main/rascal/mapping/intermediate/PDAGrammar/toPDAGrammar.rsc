module mapping::intermediate::PDAGrammar::toPDAGrammar

import util::Maybe;

import mapping::intermediate::PDAGrammar::PDAGrammar;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import Logging;
import Warning;

@doc {
    Converts the given scope grammar to a PDA grammar defining the exact same tokenization function
}
WithWarnings[PDAGrammar] toPDAGrammar(ScopeGrammar grammar, Logger log) {
    log(Section(), "to pda grammar");
    list[Warning] warnings = [];
    PDAProductions prods = ();

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
                if(scope != "") warnings += unapplicableScope(prod);

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