module conversion::determinism::combineOverlap

import Set;
import List;
import util::Maybe;
import IO;

import util::List;
import regex::Regex;
import conversion::util::makeLookahead;
import conversion::util::RegexCache;
import conversion::util::combineLabels;
import conversion::conversionGrammar::customSymbols;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import conversion::determinism::expandFollow;
import conversion::determinism::fixNullableRegexes;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::util::getEquivalentSymbols;
import conversion::shapeConversion::combineConsecutiveSymbols;
import conversion::shapeConversion::defineSequenceSymbol;
import conversion::shapeConversion::defineUnionSymbols;
import regex::PSNFATools;
import Scope;
import Warning;

data Warning = incompatibleScopesForUnion(set[tuple[Symbol, ScopeList]], set[ConvProd] productions);

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
) 
    = combineOverlapWithDefinedSymbols(grammar, maxLookaheadLength)<0, 2>;
tuple[
    list[Warning],
    set[Symbol],
    ConversionGrammar
] combineOverlapWithDefinedSymbols(
    ConversionGrammar grammar,
    int maxLookaheadLength
)
    = combineOverlapWithDefinedSymbols(grammar, grammar.productions<0>, maxLookaheadLength);
tuple[
    list[Warning],
    set[Symbol],
    ConversionGrammar
] combineOverlapWithDefinedSymbols(
    ConversionGrammar grammar,
    set[Symbol] symbols,
    int maxLookaheadLength
) {
    list[Warning] warnings = [];
    set[Symbol] allNewlyDefined = {};

    println("start-combine");
    while(size(symbols) > 0) {
        for(sym <- symbols) {
            <newWarnings, grammar> = combineOverlap(sym, grammar);
            warnings += newWarnings;
        }

        <uWarnings, newlyDefined, grammar> = defineUnionSymbols(grammar);
        grammar = fixOverlap(grammar, newlyDefined, maxLookaheadLength);
        <fWarnings, grammar> = fixNullableRegexes(grammar, newlyDefined);

        allNewlyDefined += newlyDefined;
        symbols = newlyDefined;

        warnings += uWarnings + fWarnings;
    }
    return <warnings, allNewlyDefined, grammar>;
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
                println("Combining overlap");
                <newWarnings, grammar> = combineProductions(overlap+prod, grammar);
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

    // Try to extend the prefix and suffix as far as possible
    list[ConvSymbol] findCommon(Maybe[ConvSymbol](list[ConvSymbol] parts, int index) getPart) {
        list[ConvSymbol] out = [];
        int i = 0;
        outer: while(true) {
            bool same = true;
            part = getPart(leading.parts, i);

            set[tuple[Symbol, ScopeList]] incompatibleScopes = {};
            set[ConvProd] incompatibleScopesSources = {};

            // Check if all symbols are equivalent 
            for(p:convProd(_, parts, _) <- rest) {
                comparePart = getPart(parts, i);
                if(just(regexp(r)) := part) {
                    if (just(regexp(r2)) := comparePart){
                        if(!regex::PSNFATools::equals(r, r2, true))
                            same = false;
                    } else same = false;
                } else if(just(symb(ref, scopes)) := part) {
                    if (just(symb(ref2, scopes2)) := comparePart) {
                        if(ref != ref2) 
                            same = false;
                        else if(scopes != scopes2) {
                            incompatibleScopes += {<ref2, scopes2>, <ref, scopes>};
                            incompatibleScopesSources += {p, leading};
                        }
                    } else same = false;
                } else same = false;

                if(!same) break outer;
            }

            // Add warnings if scopes are incompatible
            if(same && size(incompatibleScopes)>0)
                warnings += incompatibleScopesForUnion(
                    incompatibleScopes, 
                    incompatibleScopesSources
                );

            if(just(p) := part) out += p;
            else break outer;
            i += 1;
        }

        while([*firstSymbols, lastSymbol] := out, regexp(_) !:= lastSymbol)
            out = firstSymbols; // Make sure we end on a regular expression

        return out;
    }

    prefix += findCommon(Maybe[ConvSymbol](list[ConvSymbol] parts, int index) {
        index += 1; // Skip the first index, since it's always included
        if(index < size(parts)) return just(parts[index]);
        return nothing();
    });
    suffix = reverse(findCommon(Maybe[ConvSymbol](list[ConvSymbol] parts, int index) {
        index = size(parts) - index - 1; // Start at the end
        if(size(prefix) <= index && index < size(parts)) return just(parts[index]);
        return nothing();
    }));

    // Create the new combined production
    set[Symbol] sequences = {};
    for(p:convProd(_, parts, _) <- leading + rest) {
        startIndex = size(prefix);
        endIndex = size(parts) - size(suffix);
        remainder = parts[startIndex..endIndex];

        // If we have a common suffix, add a lookahead to prevent symbol merging in sequence
        if([regexp(r), *_] := suffix) {
            la = makeLookahead(r);
            remainder += regexp(la);
        }

        <dWarnings, seqSym, grammar> 
            = defineSequenceSymbol(remainder, p, grammar);
        warnings += dWarnings;

        sequences += seqSym;
    }
    <nWarnings, grammar, options> = normalizeUnionParts(sequences, grammar);
    warnings += nWarnings;

    combinedParts = [*prefix, symb(unionRec(options), []), *suffix];

    // Create the final production
    outProd = convProd(
        combineLabels(leading.symb, {s | convProd(s, _, _) <- leading + rest}),
        combinedParts,
        {convProdSource(p) | p <- leading + rest}
    );

    return <warnings, outProd, grammar>;
}
