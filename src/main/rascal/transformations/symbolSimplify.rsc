@synopsis{Grammar symbol simplification for readability}
@description{
    Tools for creating simpler symbols for grammars, in order to output a readable grammar
}

module transformations::SymbolSimplify

import util::Maybe;
import Grammar;
import ParseTree;
import Map;
import Set;

Grammar simplifySymbols(Grammar gr) {
    reachableRules = getUsedRules(gr.starts, gr.rules);

    map[Symbol, Symbol] names = ();
    set[Symbol] taken = {};
    for(Symbol name <- reachableRules) {
        int i=0;
        str base = "G_";
        newName = sort(base+"<i>");
        if(just(n) := getName(name)) {
            base = n;
            newName = sort(n);
        }
        
        while(newName in taken) {
            i += 1;
            newName = sort(base+"<i>");
        }

        taken += newName;
        // names += ()
        names[name] = newName;
    }

    set[Symbol] newStarts = toRel(names)[gr.starts];
    set[Production] newProds = {};
    for(Symbol name <- reachableRules)
        newProds += removeRedundant(replaceNames(gr.rules[name], names));

    return grammar(newStarts, newProds);
}

Maybe[str] getName(Symbol symbol) {
    visit(symbol) {
        case sort(name): return just(name);
    }
    return nothing();
}

Production replaceNames(Production prod, map[Symbol, Symbol] names) = top-down visit(prod) {
    case Symbol sym => names[sym]
        when sym in names
};

Production removeRedundant(Production prod) = top-down visit(prod) {
    case set[Production] prods => {p | p <- prods, !(regular(_) := p)}
};

map[Symbol, Production] getUsedRules(set[Symbol] starts, map[Symbol, Production] rules) {
    rulesRel = toRel(rules);

    rel[Symbol, Production] reachable = {<sym, prod> | <sym, prod> <- rulesRel, sym in starts};
    extended = extendReachable(reachable, rulesRel);
    while(reachable != extended) {
        reachable = extended;
        extended = extendReachable(reachable, rulesRel);
    }

    return toMapUnique(reachable);
}


rel[Symbol, Production] extendReachable(
    rel[Symbol, Production] reachable, 
    rel[Symbol, Production] allRules
) = reachable + {<sym, prod> | <sym, prod> <- allRules, isUsed(sym, reachable)};

bool isUsed(Symbol name, map[Symbol, Production] rules) {
    visit(rules) {
        case Symbol sym: if(sym == name) return true;
    }
    return false;
}
bool isUsed(Symbol name, rel[Symbol, Production] rules) {
    visit(rules) {
        case Symbol sym: if(sym == name) return true;
    }
    return false;
}
// bool isUsed(Symbol name, map[Symbol sort, Production def] rules) = name := \rules;