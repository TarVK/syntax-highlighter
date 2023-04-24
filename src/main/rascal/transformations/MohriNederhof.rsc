@synopsis{MohriNederhof approximation}
@description{
    A function to obtain the MohriNederhof (regular) approximation of a given grammar
}

module transformations::MohriNederhof

import Grammar;
import ParseTree;
import IO;

import transformations::util::GrammarComponents;
import transformations::util::GetBaseDependency;

data Symbol = Continuation(Symbol of);
data Attr = prodSource(Symbol def, list[Symbol] symbols, set[Attr] attributes, int startIndex);

@doc {
    Applies the Mohri-Nederhof algorithm on the given grammar. Expects the input grammar to be normalized. Attributes are forwarded in derived rules. 
}
Grammar approximateMohriNederhof(Grammar gr) {
    components = getGrammarComponents(gr);

    set[Production] prods = {};
    for(component <- components)
        prods += processComponent(gr.rules, component);

    return grammar(gr.starts, prods);
}

set[Production] processComponent(map[Symbol, Production] productions, set[Symbol] component) {
    set[Production] out = {};

    // Step 1
    for(sym <- component) out += prod(Continuation(sym), [], {});

    // Step 2
    for(sym <- component, dProd(_, rhs, attributes) <- choices(productions[sym])) {
        list[list[Symbol]] parts = split(rhs, component);

        if([*list[Symbol] beginning, list[Symbol] last] := parts) {
            Symbol def = sym;
            int index = 0;

            // Handle the items 0 to m-1 (which end in symbols of the rhs)
            for(defParts <- beginning) {
                out += prod(def, defParts, {prodSource(sym, rhs, attributes, index)});
                if([*_, lastSym] := defParts) def = Continuation(lastSym);
                index += size(defParts);
            }

            // Handle the special last case (which ends in the continuation of this production)
            out += prod(def, [*last, Continuation(sym)], {prodSource(sym, rhs, attributes, index)});
        }
    }

    return out;
}


// Helpers
data Prod = dProd(Symbol def, list[Symbol] symbols, set[Attr] attributes);
set[Prod] choices(Production prod) {
    switch(prod) {
        case prod(def, symbols, attr): return {dProd(def, symbols, attr)};
        case choice(_, alts): return {*choices(pr) | pr <- alts};
        default: return {};
    }
}

list[list[Symbol]] split(list[Symbol] parts, set[Symbol] component) {
    list[list[Symbol]] out = [];
    list[Symbol] cur = [];
    for(sym <- parts) {
        cur += sym;
        if(getBaseDependency(sym) in component) {
            out += [cur];
            cur = [];
        }
    }
    out += [cur];
    return out;
}