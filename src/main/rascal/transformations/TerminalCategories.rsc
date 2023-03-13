
@synopsis{Terminal category tools}
@description{
    Tools for pushing category data from non-terminal rules all the way down to the terminals,
    or instead combine shared categories and push them up the non-terminals as far as possible.
}

module transformations::TerminalCategories
extend ParseTree;

import Type;
import List;
import Grammar;
import IO;

import util::Grammar;
import util::List;

alias Categories = list[str];
data Symbol = \categorised(Symbol symbol, Categories categories);
alias CategoriesCombiner = Categories(Categories oldCategories, Categories newCategories); 

Symbol categorised(Symbol symbol, Categories categories) {
    if(size(categories) == 0) return symbol;
    fail;
}

@dox{
    This function expects the given grammar to be normalized
}
Grammar pushCategoriesToTerminals(
    Grammar input, 
    CategoriesCombiner combine
) {
    set[Symbol] handled = {};
    Productions prods = {};
    for(sym <- input.starts) {
        childProds = getGrammarProds(sym, [], handled, input, combine);
        prods += childProds;
        handled += childProds<0>;
    }

    return grammar(input.starts, prods<1>);
}

alias Productions = rel[Symbol def, Production prod];
Productions getGrammarProds(
    Symbol symbol, 
    Categories categories, 
    set[Symbol] handled,
    Grammar source, 
    CategoriesCombiner combine
) {
    withCategories = categorised(symbol, categories);
    if(withCategories in handled || isTerminal(withCategories)) return {};

    if(isTerminal(symbol)) {
        attributes = {\tag("category"(cat)) | cat <- categories}; // + {\tag(categories)};
        return {<withCategories, prod(withCategories, [symbol], attributes)>};
    }

    Productions prods = {};
    handled += withCategories;
    for(categorisedProd(_, symbols, attributes, extraCategories) <- choices(source.rules[symbol])) {
        newCategories = combine(categories, extraCategories);
        prods += <withCategories, prod(withCategories, [categorised(sym, newCategories) | sym <- symbols], attributes)>;
        
        for(sym <- symbols)  {
            childProds = getGrammarProds(sym, newCategories, handled, source, combine);
            prods += childProds;
            handled += childProds<0>;
        }
    }
    return prods;
}

// Combination approaches
Categories ancestorCategories(Categories oldCategories, Categories newCategories) = merge(oldCategories, newCategories);
Categories latestCategories(Categories oldCategories, Categories newCategories) = size(newCategories) > 0 ? newCategories : oldCategories;

// Helpers
bool isTerminal(\char-class(_)) = true;
bool isTerminal(Symbol symbol) = false;

data Prod = categorisedProd(Symbol def, list[Symbol] symbols, set[Attr] attributes, Categories categories);
Prod categorisedProd(Symbol def, list[Symbol] symbols, set[Attr] attributes) 
    = categorisedProd(def, symbols, 
        {attr | attr <- attributes, !(\tag("category"(_)) := attr)}, 
        [cat | \tag("category"(cat)) <- attributes]);

set[Prod] choices(Production prod) {
    switch(prod) {
        case prod(def, symbols, attr): return {categorisedProd(def, symbols, attr)};
        case choice(def, alts): return {*choices(pr) | pr <- alts};
        default: return {};
    }
}