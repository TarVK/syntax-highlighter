module conversion::determinism::combineOverlap

import Set;
import util::Maybe;
import IO;

import util::List;
import regex::Regex;
import conversion::util::RegexCache;
import conversion::util::combineLabels;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::determinism::expandFollow;
import conversion::shapeConversion::customSymbols;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::shapeConversion::defineSequenceSymbol;
import conversion::shapeConversion::defineUnionSymbols;
import regex::PSNFATools;
import Scope;
import Warning;

data Warning = incompatibleScopesForUnion(set[tuple[Symbol, Scopes]], set[ConvProd] productions);

@doc {
    Attempts to combine productions that start with overlapping regular expressions

    E.g.
    ```
    A -> X B
    A -> X C
    ```
    =>
    ```
    A -> X BC
    BC -> ...B
    BC -> ...C
    ```
}
WithWarnings[ConversionGrammar] combineOverlap(
    ConversionGrammar grammar, 
    int maxLookaheadLength
) {
    list[Warning] warnings = [];

    println("start-combine");

    symbols = grammar.productions<0>;
    while(size(symbols) > 0) {
        println("Detect");
        for(sym <- symbols) {
            <newWarnings, grammar> = combineOverlap(sym, grammar);
            warnings += newWarnings;
        }

        <newWarnings, symbols, grammar> = defineUnionSymbols(grammar);
        grammar = fixOverlap(grammar, symbols, maxLookaheadLength);
        warnings += newWarnings;
        // break;
    }
    return <warnings, grammar>;
}

WithWarnings[ConversionGrammar] combineOverlap(
    Symbol sym, 
    ConversionGrammar grammar
) {
    bool stable = false;
    list[Warning] warnings = [];
    while(!stable) {
        prods = [p | p <- grammar.productions[sym]];
        stable = true;

        for(
            i <- [0..size(prods)], 
            prod:convProd(_, [regexp(rm), *_], _) := prods[i],
            !acceptsEmpty(rm)
        ) {
            set[ConvProd] overlap = {
                p
                | p:convProd(_, [regexp(ri), *_], _) <- prods,
                p != prod,
                just(_) := getOverlap(ri, rm) || just(_) := getOverlap(rm, ri)
            }; 

            if(size(overlap) > 0) {
                <newWarnings, grammar> = combineProductions(overlap+prod, grammar);
                println("Detect2");
                warnings += newWarnings;
                stable = false;
                break;
            }
        }
    }

    return <warnings, grammar>;
}

WithWarnings[ConversionGrammar] combineProductions(
    set[ConvProd] prods, 
    ConversionGrammar grammar
) {
    <warnings, outProd, grammar> = getCombinedProd(prods, grammar);

    grammar.productions -= {<getWithoutLabel(s), p> | p:convProd(s, _, _) <- prods};
    grammar.productions += {<getWithoutLabel(outProd.symb), outProd>};

    return <warnings, grammar>;
}

tuple[
    list[Warning],
    ConvProd,
    ConversionGrammar
] getCombinedProd(  
    {leading, *rest}, 
    ConversionGrammar grammar
) {
    list[Warning] warnings = [];

    minLength = size(leading.parts);
    for(convProd(_, parts, _) <- rest, size(parts) < minLength)
        minLength = size(parts);

    // Make sure the first regex is always included in the prefix
    list[ConvSymbol] prefix = [];
    if(convProd(_, [regexp(r), *_], _) := leading) {
        Regex startRegex = r;
        for(p:convProd(_, [regexp(r2), *_], _) <- rest) {
            if(isSubset(r2, r)) continue;
            if(isSubset(r, r2)) {
                r = r2;
                continue;
            }
            r = getCachedRegex(alternation(r, r2));
        }

        prefix += regexp(r);
    }

    // Try to extend the prefix as far as possible
    for(i <- [1..minLength]) {
        bool same = true;
        part = leading.parts[i];

        set[tuple[Symbol, Scopes]] incompatibleScopes = {};
        set[ConvProd] incompatibleScopesSources = {};

        // Check if all symbols are equivalent 
        for(p:convProd(_, parts, _) <- rest) {
            if(regexp(r) := part) {
                if (regexp(r2) := parts[i]){
                    if(!regex::PSNFATools::equals(r, r2, true))
                        same = false;
                } else same = false;
            } else if(symb(ref, scopes) := part) {
                if (symb(ref2, scopes2) := parts[i]) {
                    if(ref != ref2) 
                        same = false;
                    else if(scopes != scopes2) {
                        incompatibleScopes += {<ref2, scopes2>, <ref, scopes>};
                        incompatibleScopesSources += {p, leading};
                    }
                } else same = false;
            }

            if(!same) break;
        }

        // Add warnings if scopes are incompatible
        if(same && size(incompatibleScopes)>0)
            warnings += incompatibleScopesForUnion(
                incompatibleScopes, 
                incompatibleScopesSources
            );

        prefix += part;
    }

    // Make sure we end on a regular expression
    while([*prefixStart, prefixEnd] := prefix, regexp(_) !:= prefixEnd)
        prefix = prefixStart;

    // TODO: also generate a common suffix in the same way

    // Create the new combined production
    set[Symbol] sequences = {};
    for(p:convProd(_, parts, _) <- leading + rest) {
        remainder = parts[size(prefix)..];

        <dWarnings, seqSym, grammar> 
            = defineSequenceSymbol(remainder, {convProdSource(p)}, grammar);
        warnings += dWarnings;

        sequences += seqSym;
    }
    combinedParts = [*prefix, symb(unionRec({}, sequences), [])];

    // Create the final production
    outProd = convProd(
        combineLabels(leading.symb, {s | convProd(s, _, _) <- leading + rest}),
        combinedParts,
        {convProdSource(p) | p <- leading + rest}
    );

    return <warnings, outProd, grammar>;
}


// @doc {
//     Follows an alias symbol until the defining symbol that it's an alias is for is reached
// }
// Symbol followAliases(Symbol sym, ConversionGrammar grammar) {
//     while({convProd(_, [symb(ref, _)], _)} := grammar.productions[sym]) {
//         sym = getWithoutLabel(ref);
//     }
//     return sym;
// }

// tuple[set[Symbol] modifiedSymbols, ConversionGrammar] addRegexToSymbol()