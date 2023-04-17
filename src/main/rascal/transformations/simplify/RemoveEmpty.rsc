module transformations::simplify::RemoveEmpty

import Type;
import ParseTree;
import Grammar;
import List;
import IO;

Grammar removeEmpty(Grammar gr) {
    changed = true;
    while(changed){
        changed = false;
        if(grammar(_, rules) := gr) {
            emptyRules = [name | name <- rules, rule := rules[name], isEmpty(rule)];

            if(size(emptyRules) > 0) {
                changed = true;
                for(rule <- emptyRules) {
                    gr = removeEmpty(gr, rule);
                }
            }
        }
    }

    return gr;
}

Grammar removeEmpty(grammar(startr, rules), Symbol sym) {
    rules = (name: rules[name] | name <- rules, name != sym);
    filteredRules = visit(rules) {
        case list[Symbol] symbols => [symbol | symbol <- symbols, symbol != sym]
    }
    return grammar(startr, filteredRules);
}

bool isEmpty(choice(_, opts)) = (true | it && isEmpty(p) | p <- opts);
bool isEmpty(prod(_, [], _)) = true;
bool isEmpty(_) = false;