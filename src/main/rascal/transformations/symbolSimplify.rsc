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
import IO;

Grammar simplifySymbols(Grammar gr) {
    map[Symbol, Symbol] names = ();
    set[Symbol] taken = {};
    for(Symbol name <- gr.rules) {
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
        names[name] = newName;
    }

    set[Symbol] newStarts = toRel(names)[gr.starts];
    set[Production] newProds = {};
    for(Symbol name <- gr.rules)
        newProds += removeRedundant(replaceNames(gr.rules[name], names));

    return grammar(newStarts, newProds);
}

Maybe[str] getName(Symbol symbol) {
    visit(symbol) {
        case sort(name): return just(name);
        case lex(name): return just(name);
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
