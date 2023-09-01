module conversion::determinism::defineUnionSymbols

import ParseTree;
import Relation;
import IO;
import util::Maybe;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::unionSym;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::shapeConversion::deduplicateProductions;
import conversion::util::RegexCache;
import regex::Regex;
import regex::PSNFATools;
import Visualize;
import Warning;


@doc {
    Defines all unioSymbols that are used in the grammar, but not yet defined in the grammar.
    Returns the set of newly created (reduced) union symbols (that aren't aliases for other symbols), together with the resulting grammar
}
tuple[list[Warning], set[Symbol], ConversionGrammar] defineUnionSymbols(ConversionGrammar grammar) {
    orGrammar = grammar;

    set[Symbol] newlyDefined = {};

    set[Symbol] unionSyms = {};
    for(<_, convProd(_, parts, _)> <- grammar.productions) {
        unionSyms += {s | symb(s:custom("union", annotate(\alt(_), _)), _) <- parts};
        unionSyms += {s | symb(label(_, s:custom("union", annotate(\alt(_), _))), _) <- parts};
    }

    // First add all union symbols without simplication
    undefinedUnionSyms = {sym | sym <- unionSyms, size(grammar.productions[sym])==0};
    if(size(undefinedUnionSyms)==0) return <[], {}, grammar>;
    for(unionSym <- undefinedUnionSyms) {
        <newSymM, grammar> = addUnionSymbol(unionSym, grammar, {}); // Skip subset simplficiation for now
        if(just(newSym) := newSymM) newlyDefined += newSym;
    }

    // Then simplify things by deduplicating
    grammar = deduplicateProductionsRespectingUnions(grammar);

    // The defined union symbols will have two consecutive symbols at the end, we need to remove these
    <warnings, grammar> = combineConsecutiveSymbols(grammar);
    
    return <warnings, newlyDefined, grammar>;
}

bool exists(Symbol s, ConversionGrammar grammar) = size(grammar.productions[s]) != 0;

tuple[Maybe[Symbol], ConversionGrammar] addUnionSymbol(
    s:custom("union", annotate(\alt(options), annotations)), 
    ConversionGrammar grammar,
    rel[Symbol, Symbol] subsets
) {
    if(exists(s, grammar)) return <nothing(), grammar>;

    universalS = unionUniversalSym(s);
    if(exists(universalS, grammar)) {
        grammar.productions += {<s, convProd(s, [symb(universalS, [])], {})>};

        return <nothing(), grammar>;
    } else {
        grammar = addUnionImplementationSymbol(s, grammar, subsets);
        grammar.productions += {<universalS, convProd(universalS, [symb(s, [])], {})>};

        return <just(s), grammar>;
    }
}

Symbol unionUniversalSym(custom("union", annotate(\alt(options), annotations))) 
    = custom(
        "unionU", 
        annotate(
            \alt(options), 
            {regexProd(r, {}) | regexProd(r, _) <- annotations}
        )
    );

ConversionGrammar addUnionImplementationSymbol(
    s:custom("union", annotate(\alt(options), annotations)), 
    ConversionGrammar grammar,
    rel[Symbol, Symbol] subsets
) {
    if(exists(s, grammar)) return grammar;

    sourceProds = {
                    convProd(copyLabel(lDef, s), size(parts)==0?[]:[*parts, symb(s, [])], {convProdSource(p)}) 
                    | sym <- options, p:convProd(lDef, parts, _) <- grammar.productions[sym]}
                + {
                    convProd(s, [regexp(r), symb(s, [])], sources)
                    | regexProd(r, sources) <- annotations
                };

    set[ConvProd] remainingProds = sourceProds;
    set[ConvProd] newProds = {};
    while(size(remainingProds) > 0) {
        <p, remainingProds> = takeOneFrom(remainingProds);

        bool hasProd = any(
            superProd <- newProds + remainingProds, 
            prodIsSubset(p, superProd, subsets, true)
        );
        if(hasProd) continue;

        newProds += p;
    }

    grammar.productions += {<s, prod> | prod <- newProds};
    return grammar;
}


@doc {
    Simplifies the given union symbol by removing any redudant symbols/regexes in there,
    Replaces all occurences of the simplified symbol in the grammar by the new symbol,
    And adds a definition of the symbol to the grammar if not yet present (and removes the original symbol definition from the grammar).
}
tuple[
    Maybe[Symbol] newlyDefined, 
    bool replacedOld,
    ConversionGrammar grammar
] addReducedUnionSymbol(
    s:custom("union", annotate(\alt(options), annotations)),
    ConversionGrammar grammar,
    map[Symbol, set[ConvProd]] prods,
    rel[Symbol, Symbol] subsets
) {
    regexes = removeSelfIncludedRegexes({<regex, sources> | regexProd(regex, sources) <- annotations});
    options = removeSelfIncludedProductions(options, prods, subsets);
    regexes = removeIncludedRegexesInProductions(regexes, options, prods, subsets);

    newUnion = size(regexes)==0 && {option}:=options
        ? option
        : unionSym(options, regexes);
    if(newUnion != s) {
        // Replace s with the a reference to the reduced implementation
        grammar.productions = {<sym, p> | <sym, p> <- grammar.productions, sym != s};
        grammar.productions += {<s, convProd(s, [symb(newUnion, [])], {})>};

        // If the new union is still a union, ensure it's defined:
        if(custom("union", _) := newUnion) {
            <newlyDefined, grammar> = addUnionSymbol(newUnion, grammar, subsets);
            return <newlyDefined, true, grammar>;
        }

        return <nothing(), true, grammar>;
    }
    
    return <nothing(), false, grammar>;
}

@doc {
    Removes the regular expressions that are fully incldued in the union of the remainders,
    ensuring that the returned set of regexes covers the full language specified by the input
}
set[tuple[Regex, set[SourceProd]]] removeSelfIncludedRegexes(set[tuple[Regex, set[SourceProd]]] regexes) {
    stable = false;
    SubtractCache cache = ();
    while(!stable) {
        stable = true;
        outer: for(t:<regex, _> <- regexes) {

            // restUnion = reduceAlternation(alternation([r | <r, _> <- regexes - t]));
            // if(isSubset(regex, restUnion)){
            //     regexes -= t;
            //     stable = false;
            //     break;
            // }

            // Note, the code above has the potential of catching more cases, but is also less performant
            for(<rest, _> <- regexes, rest != regex) {
                <cache, s> = isSubset(regex, rest, cache);
                if(s) {
                    regexes -= t;
                    stable = false;
                    break outer;
                }
            }
        }
    }

    return regexes;
}

@doc {
    Removes the symbols whose behavior is already fully included in the uniton of the remainders,
    ensuring that the returend set of symbols covers the full language specified by the input
}
set[Symbol] removeSelfIncludedProductions(
    set[Symbol] symbols, 
    map[Symbol, set[ConvProd]] prods,
    rel[Symbol, Symbol] subsets
) {
    stable = false;
    SubtractCache cache = ();
    bool isTarget = /"Exp" := symbols && /"Stmt" := symbols && /"A" := symbols;
    while(!stable) {
        stable = true;
        for(symbol <- symbols) {
            restProds = {*prods[sym] | sym <- symbols - symbol};
            bool included = true;

            for(prod <- prods[symbol]) {
                bool hasProd = false;
                if(isTarget) println("------");
                for(superProd <- restProds) {
                    <cache, hasProd> = prodIsSubset(prod, superProd, subsets, true, cache);

                    if(isTarget) {
                        if(just(deps) := getSubprodDependencies(prod, superProd, true, cache)<1>) {
                            println(<getConstraintDependencies(deps, subsets), deps>);
                        }
                    }
                    if(hasProd) break;
                }
                if(!hasProd) {
                    included = false;
                    if(isTarget) {
                        isSub = {a, b, *_} := symbols && /"Stmt" := a && /"A" := b
                            ? just(<a, b> in subsets)
                            : nothing();
                        println(stripSources(removeRegexCache(<"foooound", symbol, isSub, prod>)));
                    }
                    break;
                }
            }

            if(included){
                symbols -= symbol;
                stable = false;
                break;
            }
        }
    }

    return symbols;
}

@doc {
    Removes regular expressions for which their production would already be included in the set of productions defined by the given symbols
}
set[tuple[Regex, set[SourceProd]]] removeIncludedRegexesInProductions(
    set[tuple[Regex, set[SourceProd]]] regexes,
    set[Symbol] symbols, 
    map[Symbol, set[ConvProd]] prods,
    rel[Symbol, Symbol] subsets
) {
    for(t:<regex, _> <- regexes) {
        bool containsRegex = any(
            option <- symbols,
            prod <- prods[option],
            prodIsSubset(convProd(option, [regexp(regex), symb(option, [])], {}), prod, subsets, true)
        );

        if(containsRegex)
            regexes -= t;
    }

    return regexes;
}


@doc {
    Deduplicates productions by detecting productions that are homomorphic and removing these duplicates.
    This version respects unions such that unions are kept regardless of duplication.
    It also removes duplicate productions within the same symbol.
    Assumes all rules in the grammar to be right-recursive, or an empty production.
}
ConversionGrammar deduplicateProductionsRespectingUnions(ConversionGrammar grammar) 
    = deduplicateProductions(
        grammar,
        Symbol(Symbol a, Symbol b) {
            if(grammar.\start == a) return a;
            if(grammar.\start == b) return b;
            if(custom("unionU", _) := a) return b;
            if(custom("unionU", _) := b) return a;
            if(custom("union", _) := a) return b;
            if(custom("union", _) := b) return a;
            return a;
        },
        DedupeType(Symbol s) {
            switch(s) {
                case custom("unionU", _): return reference();
                case custom("union", _): return reference();
                default: return replace();
            }
        }
    );

// @doc {
//     Defines all unioSymbols that are used in the grammar, but not yet defined in the grammar.
//     Returns the set of newly defined (reduced) union symbols, together with the resulting grammar
// }
// tuple[list[Warning], set[Symbol], ConversionGrammar] defineUnionSymbols(ConversionGrammar grammar) {
//     orGrammar = grammar;

//     set[Symbol] unionSyms = {};
//     for(<_, convProd(_, parts, _)> <- grammar.productions) {
//         unionSyms += {s | symb(s:custom("union", annotate(\alt(_), _)), _) <- parts};
//         unionSyms += {s | symb(label(_, s:custom("union", annotate(\alt(_), _))), _) <- parts};
//     }

//     // First add all union symbols without simplication
//     undefinedUnionSyms = {sym | sym <- unionSyms, size(grammar.productions[sym])==0};
//     if(size(undefinedUnionSyms)==0) return <warnings, {}, grammar>;
//     println(undefinedUnionSyms);
//     for(unionSym <- undefinedUnionSyms) 
//         grammar = addUnionSymbol(unionSym, grammar, {}); // Skip subset simplficiation for now

//     // Then calculate all subsets and perform simplification
//     subsets = getSubsetSymbols(grammar);
//     grammar.productions = {p | p:<s, _> <- grammar.productions, s notin undefinedUnionSyms}; // Remove the previously defined unions, since we can now simplify them more using the subsets
//     map[Symbol, set[ConvProd]] prods = Relation::index(grammar.productions);
//     set[Symbol] defined = {};
//     for(unionSym <- undefinedUnionSyms) {
//         <newUnion, grammar> = addReducedUnionSymbol(unionSym, grammar, prods, subsets);

//         wasUndefined = size(orGrammar.productions[newUnion]) == 0;
//         if(wasUndefined) defined += newUnion;
//     }

//     // The defined union symbols will have two consecutive symbols at the end, we need to remove these
//     <warnings, grammar> = combineConsecutiveSymbols(grammar);

//     return <warnings, defined, grammar>;
// }

// @doc {
//     Strips the sources from the given union symbol (and all its references),
//     adds a definition for the given union symbol to the grammar if not present already,
//     leaving out productions that define a language already included in the other productions
// }
// ConversionGrammar addUnionSymbol(
//     sWithSources:custom("union", annotate(\alt(options), annotations)), 
//     ConversionGrammar grammar,
//     rel[Symbol, Symbol] subsets
// ) {
//     s = removeRegexSources(sWithSources);
//     grammar = replaceSymbol(sWithSources, s, grammar);
//     if(size(grammar.productions[s]) != 0) return grammar;

//     sourceProds = {
//                     convProd(copyLabel(lDef, s), size(parts)==0?[]:[*parts, symb(s, [])], {convProdSource(p)}) 
//                     | sym <- options, p:convProd(lDef, parts, _) <- grammar.productions[sym]}
//                 + {
//                     convProd(s, [regexp(r), symb(s, [])], sources)
//                     | regexProd(r, sources) <- annotations
//                 };

//     set[ConvProd] remainingProds = sourceProds;
//     set[ConvProd] newProds = {};
//     while(size(remainingProds) > 0) {
//         <p, remainingProds> = takeOneFrom(remainingProds);

//         bool hasProd = any(
//             superProd <- newProds + remainingProds, 
//             prodIsSubset(p, superProd, subsets, true)
//         );
//         if(hasProd) continue;

//         newProds += p;
//     }

//     grammar.productions += {<s, prod> | prod <- newProds};
//     return grammar;
// }

// @doc {
//     Simplifies the given union symbol by removing any redudant symbols/regexes in there,
//     Replaces all occurences of the simplified symbol in the grammar by the new symbol,
//     And adds a definition of the symbol to the grammar if not yet present (and removes the original symbol definition from the grammar).
// }
// tuple[Symbol, ConversionGrammar] addReducedUnionSymbol(
//     sWithSources:custom("union", annotate(\alt(options), annotations)),
//     ConversionGrammar grammar,
//     map[Symbol, set[ConvProd]] prods,
//     rel[Symbol, Symbol] subsets
// ) {
//     regexes = removeSelfIncludedRegexes({<regex, sources> | regexProd(regex, sources) <- annotations});
//     options = removeSelfIncludedProductions(options, prods, subsets);
//     regexes = removeIncludedRegexesInProductions(regexes, options, prods, subsets);

//     newUnion = size(regexes)==0 && {option}:=options
//         ? option
//         : unionSym(options, regexes);
//     s = removeRegexSources(sWithSources); // Only definitions without sources are ever present in the grammar
//     if(newUnion != s) 
//         grammar = replaceSymbol(s, newUnion, grammar);

//     if(custom("union", _) := newUnion) {
//         grammar = addUnionSymbol(newUnion, grammar, subsets);
//         newUnion = removeRegexSources(newUnion);
//     }
    
//     return <newUnion, grammar>;
// }

// @doc {
//     Removes the regular expressions that are fully incldued in the union of the remainders,
//     ensuring that the returned set of regexes covers the full language specified by the input
// }
// set[tuple[Regex, set[SourceProd]]] removeSelfIncludedRegexes(set[tuple[Regex, set[SourceProd]]] regexes) {
//     stable = false;
//     SubtractCache cache = ();
//     while(!stable) {
//         stable = true;
//         outer: for(t:<regex, _> <- regexes) {

//             // restUnion = reduceAlternation(alternation([r | <r, _> <- regexes - t]));
//             // if(isSubset(regex, restUnion)){
//             //     regexes -= t;
//             //     stable = false;
//             //     break;
//             // }

//             // Note, the code above has the potential of catching more cases, but is also less performant
//             for(<rest, _> <- regexes, rest != regex) {
//                 <cache, s> = isSubset(regex, rest, cache);
//                 if(s) {
//                     regexes -= t;
//                     stable = false;
//                     break outer;
//                 }
//             }
//         }
//     }

//     return regexes;
// }

// @doc {
//     Removes the symbols whose behavior is already fully included in the uniton of the remainders,
//     ensuring that the returend set of symbols covers the full language specified by the input
// }
// set[Symbol] removeSelfIncludedProductions(
//     set[Symbol] symbols, 
//     map[Symbol, set[ConvProd]] prods,
//     rel[Symbol, Symbol] subsets
// ) {
//     stable = false;
//     while(!stable) {
//         stable = true;
//         for(symbol <- symbols) {
//             restProds = {*prods[sym] | sym <- symbols - symbol};
//             bool included = true;

//             for(prod <- prods[symbol]) {
//                 bool hasProd = any(
//                     superProd <- restProds, 
//                     prodIsSubset(prod, superProd, subsets, true)
//                 );
//                 if(!hasProd) {
//                     included = false;
//                     break;
//                 }
//             }

//             if(included){
//                 symbols -= symbol;
//                 stable = false;
//                 break;
//             }
//         }
//     }

//     return symbols;
// }

// @doc {
//     Removes regular expressions for which their production would already be included in the set of productions defined by the given symbols
// }
// set[tuple[Regex, set[SourceProd]]] removeIncludedRegexesInProductions(
//     set[tuple[Regex, set[SourceProd]]] regexes,
//     set[Symbol] symbols, 
//     map[Symbol, set[ConvProd]] prods,
//     rel[Symbol, Symbol] subsets
// ) {
//     for(t:<regex, _> <- regexes) {
//         bool containsRegex = any(
//             option <- symbols,
//             prod <- prods[option],
//             prodIsSubset(convProd(option, [regexp(regex), symb(option, [])], {}), prod, subsets, true)
//         );

//         if(containsRegex)
//             regexes -= t;
//     }

//     return regexes;
// }