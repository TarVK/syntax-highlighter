module conversion::shapeConversion::combineConsecutiveSymbols

import ParseTree;
import Set;
import List;
import IO;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::util::overlapsAlternation;
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
    i = 0;
    do{
        prevGrammar = grammar;
        for(<sym, prod> <- grammar.productions) {
            <newWarnings, grammar> = combineConsecutiveSymbols(prod, grammar);
            warnings += newWarnings;
        }

        // TODO: get rid of this, once stable
        i += 1;
        if(i > 2) break;
    } while (prevGrammar != grammar);

    return <warnings, grammar>;
}

WithWarnings[ConversionGrammar] combineConsecutiveSymbols(prod:convProd(lDef, parts, sources), ConversionGrammar grammar) {
    list[Warning] warnings = [];

    bool modified = false;
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
        if(symb(ref, scopes) := part) {
            if (just(<prevRef, prevScopes>) := prevSymbol) {
                if(prevScopes != scopes)
                    warnings += incompatibleScopesForUnion({<rf, scopes>, <prevRef, prevScopes>}, prod);

                modified = true;
                <newWarnings, grammar, newSymbol> = combineSymbols(ref, prevRef, spacerRegex, prod, grammar);
                warnings += newWarnings;
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


tuple[list[Warning], ConversionGrammar, Symbol] combineSymbols(
    Symbol ref, 
    Symbol prevRef, 
    Maybe[Regex] spacerRegex, 
    ConvProd source,
    ConversionGrammar grammar
) { 
    list[Warning] warnings = [];
    void logConflicts(rel[ConvSymbol, ConvSymbol] conflicts) {
        for(<symb(ref1, scopes1), symb(ref2, scopes2)> <- conflicts)
            warnings += incompatibleScopesForUnion(
                {<ref1, scopes1>, <ref2, scopes2>}, p);
    }

    // Retrieve data for comparison (including the regular expression if specified)
    pureRef = getWithoutLabel(ref);
    purePrevRef = getWithoutLabel(prevRef);

    refProds = grammar.productions[pureRef];
    refCompProds = getComparisonProds(refProds, {pureRef, purePrevRef});

    prevRefProds = grammar.productions[purePrevRef];
    prevRefCompProds = getComparisonProds(prevRefProds, {pureRef, purePrevRef});

    set[ConvProd] regexCompProds = just(r) := spacerRegex
        ? {convProd(self(), [regexp(r), self()], {convProdSource(source)})}
        : {};

    // Check if one set of productions is already contained in the other
    Maybe[tuple[Symbol, set[ConvProd]]] superset = nothing();

    bool refIncluded = isSubset(refCompProds, prevRefCompProds + regexCompProds);
    bool prevRefIncluded = isSubset(prevRefCompProds, refCompProds + regexCompProds);
    bool regexIncludedInRef = isSubset(regexCompProds, refCompProds);
    bool regexIncludedInPrevRef = isSubset(regexCompProds, prevRefCompProds);

    if(refIncluded && regexIncludedInPrevRef) 
        superset = just(<purePrevRef, prevRefProds>);
    else if(prevRefIncluded && regexIncludedInRef) 
        superset = just(<pureRef, refProds>);

    if(just(<supersetRef, supersetProds>) := superset) {
        return <warnings, grammar, supersetRef>;
    }

    // If a regular expression was added, or neither production set is a superset of the other, create a new union set of all these productions
    set[Symbol] defParts = {};
    set[Regex] expressions = {};
    set[ConvProd] prods = {};
    if(!refIncluded) {
        defParts += pureRef;
        prods += refProds;
    }
    if(!prevRefIncluded) {
        defParts += purePrevRef;
        prods += prevRefProds;
    }
    regexIncluded = regexIncludedInRef && !refIncluded || regexIncludedInPrevRef && !prevRefIncluded;
    if(!regexIncluded && just(r) := spacerRegex) {
        expressions += r;
        prods += regexCompProds;
    }

    newSym = unionSym(defParts, expressions);
    bool alreadyCreated = size(grammar.productions[newSym])>0;
    println(<refIncluded, prevRefIncluded, regexIncludedInRef, regexIncludedInPrevRef, regexCompProds, size(prods), alreadyCreated>);
    if(alreadyCreated) return <warnings, grammar, newSym>;
    
    
    rel[Symbol, ConvProd] mergedProds = {};
    for(p:convProd(lDef, parts, _) <- prods) {
        // <newParts, conflicts> = combineConsecutiveIgnoreScopes(
        //     [*parts, symb(newSym, [])], 
        //     inSetEquals({pureRef, purePrevRef, self(), newSym}, newSym)
        // );
        // logConflicts(conflicts);
        newParts = size(parts) == 0 ? [] : [*parts, symb(newSym, [])];

        mergedProds += {<newSym, convProd(copyLabel(lDef, newSym), newParts, {convProdSource(p)})>};
    }

    grammar.productions += mergedProds;
    return <warnings, grammar, newSym>;
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
    return custom("union", annotate(\alt(parts), {regexProd(r) | r <- expressions}));
}
data RegexProd = regexProd(Regex);
