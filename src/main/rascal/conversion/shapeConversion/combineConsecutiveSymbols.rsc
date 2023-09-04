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
import conversion::shapeConversion::customSymbols;
import conversion::shapeConversion::defineUnionSymbols;
import conversion::shapeConversion::defineSequenceSymbol;
import conversion::util::RegexCache;
import regex::PSNFATools;
import regex::Regex;
import Scope;
import Warning;
import Visualize;

/** Scopes can't be applied due to difference in scopes merging */
data Warning = incompatibleScopesForUnion(set[tuple[Symbol, Scopes]], ConvProd production);

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

    bool changed;
    do{
        changed = false;
        for(<sym, prod> <- grammar.productions, convProd(_, [symb(_, _)], _) !:= prod) {
            <newWarnings, changedProd, grammar> = combineConsecutiveSymbols(prod, grammar);
            warnings += newWarnings;
            if(changedProd) changed = true;
        }

        if(changed) {
            println("start");
            <unionWarnings, defined, grammar> = defineUnionSymbols(grammar);
            warnings += unionWarnings;
            println("end");

            if(size(defined)==0) break;
        }
    } while (changed);

    return <warnings, grammar>;
}

/**
    Note that we don't hve to prove that the subset relation is maintained when merging symbols. It might be maintained, or it might not be maintained. Regardless of this, if the relation is not maintained during merges, we still get the output we're after. We use the subset relation to determine whether a merge correctly maintains all tokenizations that are present in the spec. If more tokenizations are added because of a merge, we don't necessarily have to maintain those during subsequent merges, so we do not care if the subset relation now gives a false positive w.r.t. to the current grammar. We only care about the subset relation ensuring that it's correct w.r.t. the input specification, which it will be because the grammar is only ever broadened. 
*/

tuple[
    list[Warning] warnings,
    bool changed,
    ConversionGrammar grammar 
] combineConsecutiveSymbols(
    prod:convProd(lDef, parts, sources), 
    ConversionGrammar grammar
) {
    <warnings, newParts, grammar> = getCombinedConsecutiveSymbols(prod, grammar);

    if(parts == newParts) return <warnings, false, grammar>;

    pureDef = getWithoutLabel(lDef);
    grammar.productions -= {<pureDef, prod>};
    grammar.productions += {<pureDef, convProd(lDef, newParts, {convProdSource(prod)})>};
    
    return <warnings, true, grammar>;
}
tuple[
    list[Warning] warnings,
    list[ConvSymbol] parts,
    ConversionGrammar grammar
] getCombinedConsecutiveSymbols(
    prod:convProd(_, parts, _), 
    ConversionGrammar grammar
) {
    list[Warning] warnings = [];

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
                    warnings += incompatibleScopesForUnion({<ref, scopes>, <prevRef, prevScopes>}, prod);
                else if(scopes != [] && just(_) := spacerRegex)
                    warnings += incompatibleScopesForUnion({<ref, scopes>}, prod);

                <sWarnings, newSymbol, grammar> = createSequence(
                    getWithoutLabel(prevRef), 
                    spacerRegex, 
                    getWithoutLabel(ref), 
                    grammar,
                    convProdSource(prod)
                );

                prevSymbol = just(<copyLabel(prevRef, newSymbol), scopes>);
                spacerRegex = nothing();
            } else {
                prevSymbol = just(<ref, scopes>);
            }
        } else if(regexp(regex) := part) {            
            // Let A X B be a sequence of symbols in parts, where X represents regex
            // Even if X accepts an empty string, depending on the lookahead/behind of the regex, A and B might never apply at once
            // We know that A can always be skipped if X accepts the empty string without restrictions, hence we merge in this case. If X accepts the empty string with restrictions, we simply hope that the overlap with A is minimal (and we might choose to merge in a later step of the algorithm)
            if(alwaysAcceptsEmpty(regex), just(<A, _>) := prevSymbol) {
                spacerRegex = just(regex);
            } else {
                flush();
                outParts += part;    
            }
        } else outParts += part;
    }
    flush();

    return <warnings, outParts, grammar>;
}

/*
    Creates a symbol that includes the language defined by being able to perform the sequence of the three parts in a row.

    
    By default a unionRec is used:
    unionRec(startOption|regex|endOption, ())

    However if the startOption is a unionRec itself, and contains an end sequence, we take special care to not broaden the language too much.

    E.g. for input `startOption = {unionRec(A, convSeq("smth" B))}`,
    instead of generating the standard (after normalization):
    ```
    unionRec(A|convSeq("smth" B)|endOption, ())
    ```

    We generate
    ```
    unionRec(A, convSeq("smth" unionRec(B|endOption, )))
    ```
*/
tuple[list[Warning], Symbol, ConversionGrammar] createSequence(
    Symbol startOption, 
    Maybe[Regex] regex, 
    Symbol endOption, 
    ConversionGrammar grammar,
    SourceProd source
) {
    // We can append if we have a clear end option
    if(
        unionRec(startStartOptions, startEndOptions) := startOption, 
        all(seo <- startEndOptions, convSeq(_) := seo),
        // Make sure there is a non-empty sequence
        any(seo <- startEndOptions, convSeq([f, *rest]) := seo)
    ) {
        suffix = just(r) := regex ? [regexp(r), symb(endOption, [])] : [symb(endOption, [])];
        // TODO: consider adding recursion regex to start options instead

        list[Warning] warnings = [];
        set[Symbol] endOptions = {};
        for(seqSym <- startEndOptions){
            if({p:convProd(lDef, parts, sources)} := grammar.productions[seqSym]) {
                newSources = {*sources, source};
                <cWarnings, cParts, grammar> = getCombinedConsecutiveSymbols(
                    convProd(lDef, [*parts, *suffix], newSources), 
                    grammar
                );
                warnings += cWarnings;

                <dWarnings, newSeqSym, grammar> = defineSequenceSymbol(
                    cParts, 
                    newSources, 
                    grammar
                );
                endOptions += newSeqSym;
            } else {
                println(<"Error for ", seqSym>);
            }
        }

        <nWarnings, grammar, beginOptions, endOptions> 
            = normalizeUnionParts(startStartOptions, endOptions, grammar);
        warnings += nWarnings;
        // println(removeRegexCache(<beginOptions, endOptions>));
        return <warnings, unionRec(beginOptions, endOptions), grammar>;
    }

    // Otherwise we hit the default case
    set[Symbol] recOptions = {startOption};
    if(just(r) := regex) {
        <_, seqSymbol, grammar> := defineSequenceSymbol(
            [regexp(r)], 
            {convProdSource(prod)}, 
            grammar
        );
        recOptions += seqSymbol;
    }

    // Create the parts and make sure we simplify sequences when possible
    // TODO: add a setting to choose between these
    <warnings, emptySeq, grammar> = defineSequenceSymbol([], {source}, grammar);
    <nWarnings, grammar, beginOptions, endOptions> 
        = normalizeUnionParts(recOptions+{endOption}, {emptySeq}, grammar);
        // = normalizeUnionParts(recOptions, {endOption}, grammar);

    warnings += nWarnings;
    return <warnings, unionRec(beginOptions, endOptions), grammar>;
}


tuple[
    list[Warning], 
    ConversionGrammar, 
    set[Symbol],
    set[Symbol]
] normalizeUnionParts(
    set[Symbol] recOptionsInp,
    set[Symbol] endOptionsInp,
    ConversionGrammar gr
) { 
    switch(<recOptionsInp, endOptionsInp>) {
        case <{convSeq([]), *recOptions}, endOptions>:
            return normalizeUnionParts(recOptions, endOptions, gr);
        case <{unionRec(ro, eo), *recOptions}, endOptions>:
            return normalizeUnionParts({*ro, *eo, *recOptions}, endOptions, gr);
        case <recOptions, {unionRec(ro, eo), *endOptions}>:
            return normalizeUnionParts({*ro, *recOptions}, {*eo, *endOptions}, gr);
        case <{op, *recOptions}, {op, *endOptions}>:
            return normalizeUnionParts({op, *recOptions}, endOptions, gr);
        // Remove the symbol suffix of any sequences in recursion
        case <{s:convSeq(parts:[*_, symb(_, _)]), *recOptions}, endOptions>: {
            list[Warning] warnings = [];
            sourceProd = getOneFrom(gr.productions[s]);
            while([*partsPrefix, symb(ref, scopes)] := parts) {
                parts = partsPrefix;
                recOptions += ref;
                if(size(scopes)>0)
                    warnings += incompatibleScopesForUnion({<ref, scopes>}, sourceProd);
            }
            <sWarnings, newSeqSym, gr> 
                = defineSequenceSymbol(parts, {convProdSource(sourceProd)}, gr);
            warnings += sWarnings;

            <rWarnings, gr, ro, eo> = normalizeUnionParts({newSeqSym, *recOptions}, endOptions, gr);
            return <rWarnings + warnings, gr, ro, eo>;
        }
    }

    return <[], gr, recOptionsInp, endOptionsInp>;
}

bool containsProd(
    Symbol sym, 
    ConvProd prod,
    ConversionGrammar grammar,
    rel[Symbol, Symbol] subsets
) = any(sProd <- grammar.productions[getWithoutLabel(sym)], prodIsSubset(prod, sProd, subsets, true));