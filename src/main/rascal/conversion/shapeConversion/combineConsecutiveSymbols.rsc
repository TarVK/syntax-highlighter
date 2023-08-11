module conversion::shapeConversion::combineConsecutiveSymbols

import ParseTree;
import Set;
import List;
import IO;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::overlapsAlternation;
import conversion::shapeConversion::util::getSubsetSymbols;
import conversion::shapeConversion::util::compareProds;
import conversion::shapeConversion::util::getComparisonProds;
import conversion::util::RegexCache;
import Scope;
import Warning;
import Visualize;
import regex::PSNFATools;

data Warning = incompatibleScopesForUnion(set[tuple[Symbol, Scopes]], ConvProd source);

@doc {
    Combines all two (or more) consecutive non-terminal symbols together into their own symbol, which allows matching  of either. Assuming all rules are right-recursive, this broadens the language.
    E.g.
    ```
    A -> X C A
    C -> Y C
    ```
    =>
    ```
    A -> X CA
    C -> Y C
    CA -> X CA
    CA -> Y CA
    ```
}
WithWarnings[ConversionGrammar] combineConsecutiveSymbols(ConversionGrammar grammar) {
    list[Warning] warnings = [];

    prevGrammar = grammar;
    // i = 0;
    do{
        subsets = getSubsetSymbols(grammar, true);
        prevGrammar = grammar;
        for(<sym, prod> <- grammar.productions) {
            <newWarnings, grammar> = combineConsecutiveSymbols(prod, grammar, subsets);
            warnings += newWarnings;
        }

        // i += 1;
        // if(i > 4) break;
    } while (prevGrammar != grammar);

    return <warnings, grammar>;
}

/**
    Note that we don't hve to prove that the subset relation is maintained when merging symbols. It might be maintained, or it might not be maintained. Regardless of this, if the relation is not maintained during merges, we still get the output we're after. We use the subset relation to determine whether a merge correctly maintains all tokenizations that are present in the spec. If more tokenizations are added because of a merge, we don't necessarily have to maintain those during subsequent merges, so we do not care if the subset relation now gives a false positive w.r.t. to the current grammar. We only care about the subset relation ensuring that it's correct w.r.t. the input specification, which it will be because the grammar is only ever broadened. 
*/

WithWarnings[ConversionGrammar] combineConsecutiveSymbols(prod:convProd(lDef, parts, sources), ConversionGrammar grammar, rel[Symbol, Symbol] subsets) {
    list[Warning] warnings = [];

    bool modified = false;
    bool addedSymbol = false;
    Maybe[tuple[Symbol, Scopes]] prevSymbol = nothing();
    Maybe[Regex] spacerRegex = nothing();
    void flush() {
        if(just(<sym, scopes>) := prevSymbol) 
            outParts += symb(sym, scopes);
        prevSymbol = nothing();

        if(just(r) := spacerRegex)
            outParts += regexp(r);
        spacerRegex = nothing();
    }

    list[ConvSymbol] outParts = [];
    for(part <- parts) {
        // If a symbol was added, we will have to wait for the new subsets to be calculated in order to know how to continue merging
        if(addedSymbol) {
            flush();
            outParts += part;
            continue;
        }


        if(symb(ref, scopes) := part) {
            if (just(<prevRef, prevScopes>) := prevSymbol) {
                if(prevScopes != scopes)
                    warnings += incompatibleScopesForUnion({<rf, scopes>, <prevRef, prevScopes>}, prod);

                modified = true;
                <grammar, newSymbol, addedSymbol> = combineSymbols(
                    ref, prevRef, spacerRegex, prod, grammar, subsets
                );
                prevSymbol = just(<copyLabel(prevRef, newSymbol), scopes>);
                spacerRegex = nothing();
            } else {
                prevSymbol = just(<ref, scopes>);
            }
        } else if(regexp(regex) := part) {
            bool normalRegex = true;
            if(acceptsEmpty(regex), just(<A, _>) := prevSymbol) {
                // Let A X B be a sequence of symbols in parts, where X represents regex
                // Even if X accepts an empty string, depending on the lookahead/behind of the regex, A and B might never apply at once
                // They only apply at once, if X overlaps with an alternation of A

                overlaps = overlapsAlternation(A, regex, grammar);
                if(overlaps) {
                    spacerRegex = just(regex);
                    normalRegex = false;
                }
            }

            if(normalRegex) {
                flush();
                outParts += part;
            }
        } else outParts += part;
    }
    flush();

    if(!modified) return <warnings, grammar>;

    pureDef = getWithoutLabel(lDef);
    grammar.productions -= {<pureDef, prod>};
    grammar.productions += {<pureDef, convProd(lDef, outParts, {convProdSource(prod)})>};
    
    return <warnings, grammar>;
}

tuple[ConversionGrammar, Symbol, bool] combineSymbols(
    Symbol ref, 
    Symbol prevRef, 
    Maybe[Regex] spacerRegex, 
    ConvProd source,
    ConversionGrammar grammar,
    rel[Symbol, Symbol] subsets
) { 
    // Retrieve data for comparison (including the regular expression if specified)
    pureRef = getWithoutLabel(ref);
    purePrevRef = getWithoutLabel(prevRef);

    refProds = grammar.productions[pureRef];

    prevRefProds = grammar.productions[purePrevRef];

    // Check if one set of productions is already contained in the other
    Maybe[tuple[Symbol, set[ConvProd]]] superset = nothing();

    bool refIncluded = <pureRef, purePrevRef> in subsets;
    bool prevRefIncluded = <purePrevRef, pureRef> in subsets;

    bool regexIncluded(Symbol sym) = just(r) := spacerRegex
        ? containsProd(sym, convProd(sym, [regexp(r), symb(sym, [])], {}), grammar, subsets)
        : true;
    bool regexIncludedInRef = regexIncluded(pureRef);
    bool regexIncludedInPrevRef = regexIncluded(purePrevRef);

    if(refIncluded && regexIncludedInPrevRef) 
        superset = just(<purePrevRef, prevRefProds>);
    else if(prevRefIncluded && regexIncludedInRef) 
        superset = just(<pureRef, refProds>);

    if(just(<supersetRef, supersetProds>) := superset) {
        return <grammar, supersetRef, false>;
    }

    // If a regular expression was added, or neither production set is a superset of the other, create a new union set of all these productions
    set[Symbol] defParts = {};
    set[Regex] expressions = {};
    set[ConvProd] prods = {};
    if(!refIncluded) {
        defParts += pureRef;
        prods += refProds;
    }
    if(!(prevRefIncluded && !refIncluded)) {
        defParts += purePrevRef;
        prods += prevRefProds;
    }
    bool regexIncluded = regexIncludedInRef && !refIncluded || regexIncludedInPrevRef && !prevRefIncluded;
    if(!regexIncluded && just(r) := spacerRegex)
        expressions += r;

    newSym = unionSym(defParts, expressions);

    bool alreadyCreated = size(grammar.productions[newSym])>0;
    if(alreadyCreated) return <grammar, newSym, false>;
    
    if(!regexIncluded && just(r) := spacerRegex)
        prods += {convProd(newSym, [regexp(r), symb(newSym, [])], {convProdSource(source)})};
    
    rel[Symbol, ConvProd] mergedProds = {};
    for(p:convProd(lDef, parts, _) <- prods) {
        newParts = size(parts) == 0 ? [] : [*parts, symb(newSym, [])];
        mergedProds += {<newSym, convProd(copyLabel(lDef, newSym), newParts, {convProdSource(p)})>};
    }

    grammar.productions += mergedProds;
    return <grammar, newSym, true>;
}

@doc {
    A symbol that captures all relevant data of a derived union of multiple symbols.
    This flattens out any nested union symbols in order to remove irrelevant structural information.
    A custom symbol is used for better visualizations in Rascal-vis, but the regular expressions can only be stored as annotations.
}
Symbol unionSym(set[Symbol] parts, set[Regex] expressions) {
    // Flatten out any nested unionWSyms
    while({custom("union", annotate(\alt(iParts), annotations)), *rest} := parts) {
        for(regexProd(exp) <- annotations)
            expressions += exp;
        parts = rest + iParts;
    }

    // Create the new symbol
    return custom("union", annotate(\alt(parts), {regexProd(removeRegexCache(r)) | r <- expressions}));
}
data RegexProd = regexProd(Regex);



bool containsProd(
    Symbol sym, 
    ConvProd prod,
    ConversionGrammar grammar,
    rel[Symbol, Symbol] subsets
) = any(sProd <- grammar.productions[getWithoutLabel(sym)], prodIsSubset(prod, sProd, subsets, true));