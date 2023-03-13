module util::Grammar

import Grammar;
import ParseTree;
import IO;

Grammar add(Grammar gr, Production prod) {
    if (prod.def in gr.rules) {
        current = gr.rules[prod.def];
        gr.rules[prod.def] = choice(prod.def, {current, prod});
    } else {
        gr.rules[prod.def] = prod;
    }
    return gr;
}

bool contains(Grammar grammar, Symbol sym) = sym in grammar.rules;
