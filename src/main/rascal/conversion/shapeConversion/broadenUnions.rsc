module conversion::shapeConversion::broadenUnions

import Relation;
import Map;
import Set;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::transforms::removeUnreachable;

data BroadeningBehavior 
    /* Don't perform broadening at all, as if this function weren't even called */
    = neverBroaden()
    /* Only broaden if a set of convSequences is already reached at once elsewhere */
    | broadenIfReached()
    /* Always broaden when new convSequences are detected */
    | alwaysBroaden();

@doc {
    Broadens unions, to decrease grammar complexity and prevent exponential blowups.

    If a common set of symbols is detected to have been augmented by two different convSequences, they are combined into one since it's likely that this combined symbol is at some point also generated. E.g.:
    ```
    unionRec(A|B|convSeq(x)) -> ...
    unionRec(A|B|convSeq(y)) -> ...
    ```
    =>
    ```
    unionRec(A|B|convSeq(x)) -> unionRec(A|B|convSeq(x)|convSeq(y))
    unionRec(A|B|convSeq(y)) -> unionRec(A|B|convSeq(x)|convSeq(y))
    ```

    All generated symbols that depend on definitions of the broadened unions will be set to undefined in the resulting grammar, in order to be re-generated. 
}
tuple[
    ConversionGrammar grammar,
    map[Symbol, Symbol] broadenings
] broadenUnions(ConversionGrammar grammar, BroadeningBehavior broadenBehavior) {
    if(broadenBehavior==neverBroaden()) return <grammar, ()>;
    
    set[Symbol] definedSymbols = grammar.productions<0>;
    set[Symbol] encounteredUnions = {s | s:unionRec(_) <- getReachableSymbols(grammar, true)};

    // Collect all the convSequences that given unions are paired with
    map[set[Symbol], set[set[Symbol]]] pairedWith = index({extractSequences(parts) | unionRec(parts) <- encounteredUnions});

    // Only consider newly defined unions, in order to not repeat work
    set[Symbol] newUnions =  encounteredUnions - definedSymbols;

    // Retrieve the broadenings that should be performed, from one symbol set to another
    map[set[Symbol], set[Symbol]] broadening = ();
    for(unionRec(parts) <- newUnions) {
        <mainParts, sequences> = extractSequences(parts);

        for(otherSequences <- pairedWith[mainParts], otherSequences != sequences) {
            // If we only broaden when reached, make sure that the sequence broadened is a sub-sequence
            if(
                broadenBehavior == broadenIfReached() 
                && !(otherSequences < sequences)
            ) continue;

            allSymbols = mainParts + otherSequences;
            allNewSymbols = allSymbols + sequences;

            if(allSymbols notin broadening) broadening[allSymbols] = allNewSymbols;
            else {
                curBroadening = broadening[allSymbols];
                if(broadenBehavior == broadenIfReached()) {
                    isBetterBroadening = size(allNewSymbols) > size(curBroadening);
                    if(isBetterBroadening) 
                        broadening[allSymbols] = allNewSymbols;
                } else if(broadenBehavior == alwaysBroaden()) {
                    broadening[allSymbols] += allNewSymbols;
                }
            }
        }
    }

    // Perform broadening
    ProdMap prodMap = Relation::index(grammar.productions);
    for(dependent <- getDefinitionDependents({unionRec(from) | from <- broadening}, grammar, definedSymbols))
        prodMap = delete(prodMap, dependent);
    for(from <- broadening) {
        to = broadening[from];
        fromSym = unionRec(from);
        toSym = unionRec(to);

        prodMap[fromSym] = {convProd(label("broaden", fromSym), [ref(toSym, [], {})])};
    }

    return <
        convGrammar(grammar.\start, toRel(prodMap)),
        (unionRec(from): unionRec(broadening[from]) | from <- broadening)
    >;
}

@doc {
    Seperates the sequence symbols from all other symbols
}
tuple[
    set[Symbol] mainSymbols,
    set[Symbol] sequences
] extractSequences(set[Symbol] parts) 
    = <
        {p | p <- parts, convSeq(_) !:= p},
        {p | p <- parts, convSeq(_) := p}
    >;

@doc {
    Given a symbol A, retrieves every symbol B which used A's definition either directly or indirectly, to be defined
}
set[Symbol] getDefinitionDependents(
    set[Symbol] syms, 
    ConversionGrammar grammar, 
    set[Symbol] definedSymbols
) {
    rel[Symbol, Symbol] definitionDependencies = {};
    rel[Symbol, Symbol] usageDependencies = {};

    // Collect direct definition dependencies
    definitionDependencies += {
        <c, a>,
        <c, b>
        | c:closed(a, b) <- definedSymbols
    };
    definitionDependencies += {
        <u, part>
        | u:unionRec(parts) <- definedSymbols,
        part <- parts
    };
    
    // Collect usage dependencies
    usageDependencies += {
        <sym, dependency>
        | <sym, convProd(_, parts)> <- grammar.productions,
        ref(dependency, _, _) <- parts
    };

    // Follow dependencies in reverse direction
    map[Symbol, set[Symbol]] definitionDependents = Relation::index(definitionDependencies<1, 0>);
    map[Symbol, set[Symbol]] usageDependents = Relation::index(usageDependencies<1, 0>);

    set[Symbol] reached = {}; // Note that only closed and union symbols are added to this
    set[Symbol] queue = syms;
    while({sym, *rest} := queue) {
        queue = rest;

        /*
            We alternate between usage and definition dependencies in this search. 
            We want to find all affected definition dependencies, but these definitions might indirectly depend on a symbol, through the productions that are copied by the definition.

            Also note that we can't just assume that a defining symbol dependts on another symbol only if it directly occurs in its productions, bbecause due to all transformations performed on the productions, it might no longer be identical to the original symbol.
        */
        symDefinitionsDependents = sym in definitionDependents ? definitionDependents[sym] : {};
        if(sym in usageDependents) {
            for(symUD <- usageDependents[sym], symUD in definitionDependents)
                symDefinitionsDependents += definitionDependents[symUD];
        }
        
        newSyms = symDefinitionsDependents - reached;
        queue += newSyms;
        reached += newSyms;
    }

    return reached;
}