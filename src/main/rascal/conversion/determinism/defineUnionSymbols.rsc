module conversion::determinism::defineUnionSymbols

import ParseTree;
import Relation;
import IO;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::unionSym;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::util::RegexCache;
import regex::Regex;
import regex::PSNFATools;
import Visualize;
import Warning;

@doc {
    Defines all unioSymbols that are used in the grammar, but not yet defined in the grammar.
    Returns the set of newly defined (reduced) union symbols, together with the resulting grammar
}
tuple[list[Warning], set[Symbol], ConversionGrammar] defineUnionSymbols(ConversionGrammar grammar) {
    orGrammar = grammar;

    println("d1");
    set[Symbol] unionSyms = {};
    for(<_, convProd(_, parts, _)> <- grammar.productions) {
        unionSyms += {s | symb(s:custom("union", annotate(\alt(_), _)), _) <- parts};
        unionSyms += {s | symb(label(_, s:custom("union", annotate(\alt(_), _))), _) <- parts};
    }

    // First add all union symbols without simplication
    println("d2");
    undefinedUnionSyms = {sym | sym <- unionSyms, size(grammar.productions[sym])==0};
    for(unionSym <- undefinedUnionSyms) 
        grammar = addUnionSymbol(unionSym, grammar, {}); // Skip subset simplficiation for now

    // Then calculate all subsets and perform simplification
    println("d3");
    subsets = getSubsetSymbols(grammar);
    grammar.productions = {p | p:<s, _> <- grammar.productions, s notin undefinedUnionSyms}; // Remove the previously defined unions, since we can now simplify them more using the subsets
    map[Symbol, set[ConvProd]] prods = Relation::index(grammar.productions);
    set[Symbol] defined = {};
    println("d4");
    for(unionSym <- undefinedUnionSyms) {
        <newUnion, grammar> = addReducedUnionSymbol(unionSym, grammar, prods, subsets);

        wasUndefined = size(orGrammar.productions[newUnion]) == 0;
        if(wasUndefined) defined += newUnion;
    }

    // The defined union symbols will have two consecutive symbols at the end, we need to remove these
    println("d5");
    <warnings, grammar> = combineConsecutiveSymbols(grammar);

    println("d6");
    return <warnings, defined, grammar>;
}

@doc {
    Strips the sources from the given union symbol (and all its references),
    adds a definition for the given union symbol to the grammar if not present already,
    leaving out productions that define a language already included in the other productions
}
ConversionGrammar addUnionSymbol(
    sWithSources:custom("union", annotate(\alt(options), annotations)), 
    ConversionGrammar grammar,
    rel[Symbol, Symbol] subsets
) {
    s = removeRegexSources(sWithSources);
    grammar = replaceSymbol(sWithSources, s, grammar);
    if(size(grammar.productions[s]) != 0) return grammar;

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
tuple[Symbol, ConversionGrammar] addReducedUnionSymbol(
    sWithSources:custom("union", annotate(\alt(options), annotations)),
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
    s = removeRegexSources(sWithSources); // Only definitions without sources are ever present in the grammar
    if(newUnion != s) 
        grammar = replaceSymbol(s, newUnion, grammar);

    if(custom("union", _) := newUnion) {
        grammar = addUnionSymbol(newUnion, grammar, subsets);
        newUnion = removeRegexSources(newUnion);
    }
    
    return <newUnion, grammar>;
}

@doc {
    Removes the regular expressions that are fully incldued in the union of the remainders,
    ensuring that the returned set of regexes covers the full language specified by the input
}
set[tuple[Regex, set[SourceProd]]] removeSelfIncludedRegexes(set[tuple[Regex, set[SourceProd]]] regexes) {
    stable = false;
    while(!stable) {
        stable = true;
        for(t:<regex, _> <- regexes) {
            restUnion = reduceAlternation(alternation([r | <r, _> <- regexes - t]));
            if(isSubset(regex, restUnion)){
                regexes -= t;
                stable = false;
                break;
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
    while(!stable) {
        stable = true;
        for(symbol <- symbols) {
            restProds = {*prods[sym] | sym <- symbols - symbol};
            bool included = true;

            for(prod <- prods[symbol]) {
                bool hasProd = any(
                    superProd <- restProds, 
                    prodIsSubset(prod, superProd, subsets, true)
                );
                if(!hasProd) {
                    included = false;
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