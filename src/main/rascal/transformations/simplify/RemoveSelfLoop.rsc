module transformations::simplify::RemoveSelfLoop

import Type;
import ParseTree;
import Grammar;
import List;
import IO;

import transformations::util::GetBaseDependency;

Grammar removeSelfLoop(grammar(startr, rules)) {
    for(ruleName <- rules) {
        rule = rules[ruleName];
        rules[ruleName] = visit(rule) {
            case choice(sym, opts): {
                singleProds = {opt | opt <- opts, prod(_, [_], _) := opt};
                others = opts - singleProds;

                insert choice(sym, 
                    others + {opt | opt <- singleProds, 
                            prod(_, [ref], _) := opt, 
                            getBaseDependency(ruleName) != getBaseDependency(ref)
                    });
            }
        };
    }

    return grammar(startr, rules);
}