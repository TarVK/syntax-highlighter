module transformations::simplify::RemoveUnusedRules


import util::Maybe;
import Grammar;
import ParseTree;
import Map;
import Set;
import IO;

Grammar removeUnusedRules(Grammar gr) {
    reachableRules = getUsedRules(gr.starts, gr.rules);
    return grammar(gr.starts, reachableRules);
}

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