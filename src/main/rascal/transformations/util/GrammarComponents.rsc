@synopsis{Grammar recursion analysis}
@description{
    Tools for obtaining the mutually recursive components within a grammar
}

module transformations::util::GrammarComponents

import ParseTree;
import Grammar;
import List;
import Set;
import Map;
import Relation;

import transformations::util::GetBaseDependency;

@doc {
    Retrieves the mutually recursive symbols within the grammar
}
list[set[Symbol]] getGrammarComponents(Grammar grammar) {
    dependencies = getDependencies(grammar);
    return getSCC(dependencies);
}

map[Symbol, set[Symbol]] getDependencies(Grammar grammar) = (symbol: getDependencies(grammar.rules[symbol]) | symbol <- grammar.rules);
set[Symbol] getDependencies(Production prod) {
    set[Symbol] dependencies = {};

    visit (prod) {
        case prod(_, symbols, _): dependencies += {getBaseDependency(s) | s <- symbols};
    }

    return dependencies;
}

data OrderData[&T] = OD(
    set[&T] visited,
    list[&T] out
);
OrderData[&T] postOrder(map[&T, set[&T]] dependencies, &T sym, set[&T] visited) {
    visited += sym;
    list[&T] out = [];
    if (sym in dependencies)
        for (neighbor <- dependencies[sym])
            if (!(neighbor in visited) && neighbor in dependencies) 
                if (OD(newVisited, newOut) := postOrder(dependencies, neighbor, visited)) {
                    visited += newVisited;
                    out += newOut;
                }
    out += sym;
    return OD(visited, out);
}
list[set[&T]] getSCC(map[&T, set[&T]] dependencies) {
    list[&T] stack = [];
    set[&T] visited = {};
    
    for (sym <- dependencies)
        if (!(sym in visited))
            if (OD(newVisited, newStack) := postOrder(dependencies, sym, visited)) {
                stack += newStack;
                visited += newVisited;
            }
            
    map[&T, set[&T]] reversedDependencies = getTranspose(dependencies);
    set[&T] visited2 = {};
    list[set[&T]] components = [];
    for (sym <- reverse(stack)) 
        if (!(sym in visited2)) 
            if (OD(newVisited, component) := postOrder(reversedDependencies, sym, visited2)) {
                components += toSet(component);
                visited2 += newVisited;
            }
    return reverse(components);
}

map[&T, set[&T]] getTranspose(map[&T, set[&T]] dependencies) =
    index(toRel(dependencies)<1, 0>);
