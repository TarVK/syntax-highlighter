module conversion::shapeConversion::defineUnionSymbols

import ParseTree;
import Relation;
import IO;
import util::Maybe;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::conversionGrammar::customSymbols;
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
        unionSyms += {s | symb(s:unionRec(_), _) <- parts};
        unionSyms += {s | symb(label(_, s:unionRec(_)), _) <- parts};
    }

    // First add all union symbols without simplication
    undefinedUnionSyms = {sym | sym <- unionSyms, !exists(sym, grammar)};
    if(size(undefinedUnionSyms)==0) return <[], {}, grammar>;
    for(unionSym <- undefinedUnionSyms) {
        <newSymM, grammar> = addUnionSymbol(unionSym, grammar);
        if(just(newSym) := newSymM) newlyDefined += newSym;
    }

    // Then simplify things by deduplicating
    grammar = deduplicateProductionsRespectingUnions(grammar);

    // The defined union symbols will have two consecutive symbols at the end, we need to remove these
    <warnings, recDefined, grammar> = combineConsecutiveSymbolsWithDefinedSymbols(grammar);
    newlyDefined += recDefined;
    
    return <warnings, newlyDefined, grammar>;
}

bool exists(Symbol s, ConversionGrammar grammar) = size(grammar.productions[s]) != 0;

tuple[Maybe[Symbol], ConversionGrammar] addUnionSymbol(
    s:unionRec(recOptions),
    ConversionGrammar grammar
) {
    if(exists(s, grammar)) return <nothing(), grammar>;

    recProds = {p | sym <- recOptions, p <- grammar.productions[followAlias(sym, grammar)]};

    sourceProds = {
                    convProd(
                        copyLabel(lDef, s), 
                        size(parts)==0?[]:[*parts, symb(s, [])], // We make the production recursive
                        {convProdSource(p)}
                    ) 
                    | p:convProd(lDef, parts, _) <- recProds
                };

    grammar.productions += {<s, prod> | prod <- sourceProds};
    return <just(s), grammar>;
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
            if(unionRec(_) := a) return b; // Deprioritize unions to be kept as definitions
            if(unionRec(_) := b) return a;
            return a;
        },
        DedupeType(Symbol s) {
            // switch(s) {
            //     case unionRec(_, _): return reference(); // Never fully delete unions
            //     default: return replace();
            // }
            return reference();
        }
    );

    
// TODO: move this somewhere else if still used
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
