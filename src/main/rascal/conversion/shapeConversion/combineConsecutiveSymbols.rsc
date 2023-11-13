module conversion::shapeConversion::combineConsecutiveSymbols

import Set;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::shapeConversion::defineSequence;
import conversion::util::meta::extractSources;
import conversion::util::meta::LabelTools;
import regex::Regex;
import regex::PSNFATools;
import regex::RegexTransformations;
import Warning;
import Scope;
import Logging;

@doc {
    Combines consecutive non-terminals in all the given productions:
    ```
    A -> X A B Y A
    ```
    =>
    ```
    A -> X unionRec(A|B) Y A
    ```

    Might add convSeq symbols to the grammar in case a nullable regex is found:
    ```
    A -> X A /a?/ B Y A
    ```
    =>
    ```
    A -> X unionRec(A|B|convSeq([/a/])) Y A
    convSeq([/a/]) -> /a/ 
    ```
}
tuple[
    list[Warning] warnings,
    set[ConvProd] prods,
    ConversionGrammar grammar
] combineConsecutiveSymbols(set[ConvProd] prods, ConversionGrammar grammar, Logger log) {
    log(ProgressDetailed(), "combining consecutive symbols");
    set[ConvProd] out = {};
    list[Warning] warnings = [];
    for(p:convProd(lDef, parts) <- prods) {
        <nWarnings, newParts, grammar> = getCombinedConsecutiveSymbols(p, grammar);
        warnings += nWarnings;
        out += convProd(lDef, newParts);
    }

    return <warnings, out, grammar>;
}

@doc {
    Retrieves the combined parts for a given production,
    and augments the grammar with a `convSeq` if necessary if a nullable regex got merged
}
tuple[
    list[Warning] warnings,
    list[ConvSymbol] parts,
    ConversionGrammar grammar
] getCombinedConsecutiveSymbols(
    prod:convProd(_, parts), 
    ConversionGrammar grammar
) {
    list[Warning] warnings = [];

    Maybe[tuple[Symbol, ScopeList, set[SourceProd]]] prevSymbol = nothing();
    Maybe[Regex] spacerRegex = nothing();
    void flush() {
        if(just(<sym, scopes, sources>) := prevSymbol) 
            outParts += ref(sym, scopes, sources);
        prevSymbol = nothing();

        if(just(r) := spacerRegex)
            outParts += regexp(r);
        spacerRegex = nothing();
    }

    list[ConvSymbol] outParts = [];
    for(part <- parts) {
        if(ref(refSym, scopes, sources) := part) {
            if (just(<prevRefSym, prevScopes, prevSources>) := prevSymbol) {
                if(prevScopes != scopes) {
                    warnings += incompatibleScopesForUnion({<refSym, scopes>, <prevRefSym, prevScopes>}, prod);
                    scopes = [];
                } else if(scopes != [] && just(_) := spacerRegex) {
                    warnings += incompatibleScopesForUnion({<refSym, scopes>}, prod);
                    scopes = [];
                }

                <sWarnings, newSymbol, grammar> = createSequence(
                    getWithoutLabel(prevRefSym), 
                    spacerRegex, 
                    getWithoutLabel(refSym), 
                    grammar,
                    prod
                );
                warnings += sWarnings;

                newSources = sources + prevSources + ((just(r) := spacerRegex) ? extractSources(r) : {});
                prevSymbol = just(<copyLabel(prevRefSym, newSymbol), scopes, newSources>);
                spacerRegex = nothing();
            } else {
                prevSymbol = just(<refSym, scopes, sources>);
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

@doc {
    Creates a symbol `S` for the given start and end symbol, possibly with intermediate regular expression:
    - L(startSym regex endSym) ⊆ L(S)  

    This is done by using a union rec of the given options:
    ```
    S = unionRec(startSym|endSym|regex)
    ```
}
tuple[list[Warning], Symbol, ConversionGrammar] createSequence(
    Symbol startSym,
    Maybe[Regex] regex,
    Symbol endSym,
    ConversionGrammar grammar,
    ConvProd prod
) {
    list[Warning] warnings = [];

    set[Symbol] recOptions = {startSym, endSym};
    if(just(r) := regex) {
        <rMain, rEmpty, rEmptyRestr> = factorOutEmpty(r);
        if(rMain != never()) {
            <dWarnings, seqSymbol, grammar> = defineSequence([regexp(rMain)], prod, grammar);
            warnings += dWarnings;
            recOptions += seqSymbol;
        }
    }

    // Create the parts and make sure we simplify sequences when possible
    unionSym = simplify(unionRec(recOptions), grammar);

    return <warnings, unionSym, grammar>;
}
