module transformations::simplify::SubstituteUnitRules

import Type;
import ParseTree;
import Grammar;
import List;
import IO;

import transformations::SymbolSimplify;
import transformations::util::GetBaseDependency;


@doc {
    Substitutes unit rules when they don't have many occurences
} 
Grammar substituteUnitRules(Grammar gr, int lessthan = 9) {
    changed = false;
    do {
        changed = false;
        if(grammar(startr, rules) := gr) {
            for(choice(_, {prod(from, to, _)}) <- rules<1>
                    && !(from in startr) 
                    && occurenceCount(gr, from) < lessthan) {

                gr = replaceSymbol(gr, from, to);
                changed = true;
                break; // Don't continue with the old rules set, since reference in there are now outdated
            }
        }
    } while (changed);

    return gr;
}


int occurenceCount(grammar(_, rules), Symbol from) {
    int count = -1; // account for symbol definition
    replacedRules = visit(rules) {
        case prod(_, parts, _): visit(parts) {
            case from: count += 1;
        }
    }
    return count;
}

Grammar replaceSymbol(grammar(startr, rules), Symbol from, list[Symbol] to) {
    rules = (name: rules[name] | name <- rules, name != from);
    replacedRules = visit(rules) {
        // case list[Symbol] symbols => [symbol != from ? symbol : *to | symbol <- symbols] // Runtime errors
        case list[Symbol] symbols => [*(getBaseDependency(symbol) != getBaseDependency(from) ? [symbol] : to) | symbol <- symbols]
    }
    return grammar(startr, replacedRules);
}