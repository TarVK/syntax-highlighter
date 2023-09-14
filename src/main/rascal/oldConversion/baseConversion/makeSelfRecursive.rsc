module conversion::baseConversion::makeSelfRecursive

import util::Maybe;
import Set;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;
import conversion::util::RegexCache;

@doc {
    Makes sure all productions are self-recursive, by adding unsatisfiable regexes if needed
    E.g.
    ```
    A -> X B
    ```
    =>
    ```
    A -> X B $0 A
    ```
}
ConversionGrammar makeSelfRecursive(ConversionGrammar grammar)
    = makeSelfRecursive(grammar, grammar.productions<0>);
ConversionGrammar makeSelfRecursive(ConversionGrammar grammar, set[Symbol] symbols) {
    

    for(sym <- symbols) {
        prods = grammar.productions[sym];
        if({convProd(_, [symb(ref, [])], _)} := prods) continue;

        for(
            prod:convProd(lDef, [*parts, lastPart], sources) <- prods,
            !(symb(ref, []) := lastPart && followAlias(ref, grammar) == sym)
        ) {
            grammar.productions -= {<sym, prod>};
            grammar.productions += {<
                sym, 
                convProd(
                    lDef,
                    [*parts, lastPart, regexp(getCachedRegex(never())), symb(sym, [])],
                    sources
                )
            >};
        }
    }

    return grammar;
}