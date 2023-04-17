module transformations::RemovePriorities

import Grammar;
import ParseTree;
import Type;

Grammar removePriorities(Grammar gr) = visit(gr) {
    case priority(sym, groups) => choice(sym, {prod | prod <- groups})
    case associativity(sym, _, prods) => choice(sym, prods)
};