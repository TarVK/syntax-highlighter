module conversion::shapeConversion::makePrefixedRightRecursive

import Set;
import List;
import Relation;

import conversion::conversionGrammar::ConversionGrammar;
import Warning;
import Scope;

// The scope can't be applied to the given grammar due to left-recursion
data Warning = inapplicableScope(Scopes scope, ConvProd production);

@doc {
    Gets rid of all left-most symbols in productions, broadening the language.
    The guarantee on the output grammar is:
        - The left-most symbol of every production is a regular expression
        - The language of the output grammar contains the language of the input grammar

    E.g.
    ```
    A -> B 'a'
    B -> A 'b'
    B -> D
    D -> 'd'
    ```
    => 
    ```
    A -> 'a' A
    A -> 'b' A
    A -> 'd' A
    A -> 
    ```
}
WithWarnings[ConversionGrammar] makePrefixedRightRecursive(ConversionGrammar grammar) {
    rel[Symbol, ConvProd] outProds = {};
    list[Warning] warnings = [];

    for(sym <- grammar.productions<0>) {
        symProds = grammar.productions[sym];

        <newWarnings, newProds> = convert(sym, symProds, grammar, {});
        warnings += newWarnings;
        outProds += {<sym, newProd> | newProd:convProd(_, parts, _) <- newProds, size(parts)>1};
        outProds += <sym, convProd(label("empty", sym), [], {})>;
    }

    return <warnings, convGrammar(grammar.\start, outProds)>;
}

WithWarnings[set[ConvProd]] convert(Symbol target, set[ConvProd] prods, ConversionGrammar grammar, set[Symbol] encountered) {
    list[Warning] warnings = [];
    set[ConvProd] out = {};

    set[ConvProd] queue = prods;
    while(size(queue)>0) {
        <p, queue> = takeOneFrom(queue);
        if(convProd(lDef, parts, sources) := p){
            if([symb(ref, scopes), *rest] := parts) {
                if(size(scopes) > 0) warnings += inapplicableScope(scopes, p);
                
                if(size(rest) > 0) queue += convProd(copyLabel(lDef, target), makeLoop(target, rest), {convProdSource(p)});

                pureRef = getWithoutLabel(ref);
                refProds = grammar.productions[pureRef];
                if(pureRef in encountered) continue;
                encountered += pureRef;
                <refWarnings, newRefProds> = convert(target, refProds, grammar, encountered);

                warnings += refWarnings;
                out += newRefProds;
            } else
                out += convProd(copyLabel(lDef, target), makeLoop(target, parts), sources);
        }
    }

    return <warnings, out>;
}

list[ConvSymbol] makeLoop(Symbol target, list[ConvSymbol] symbols) {
    if([*rest, symb(ref, [])] := symbols) {
        if(getWithoutLabel(ref) == getWithoutLabel(target)) return symbols;
    }
    return [*symbols, symb(target, [])];
}
