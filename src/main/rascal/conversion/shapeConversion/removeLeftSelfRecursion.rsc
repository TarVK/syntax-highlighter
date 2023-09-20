module conversion::shapeConversion::removeLeftSelfRecursion

import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import regex::RegexTypes;
import regex::regexToPSNFA;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::RegexTransformations;

@doc {
    Removes left self-recursion, e.g.:
    ```
    A -> /(>X)|Y/ A x
    ```
    =>
    ```
    A -> x
    A -> Y A x
    ```
}
set[ConvProd] removeLeftSelfRecursion(set[ConvProd] prods) {
    set[ConvProd] out = {};

    for(p:convProd(lDef, parts) <- prods) {
        def = getWithoutLabel(lDef);
        
        if(parts == []) {
            out += p;
            continue;
        }

        while(
            [regexp(r), *regexes, symRef:ref(sym, _, _), *rest] := parts,
            getWithoutLabel(sym) == def,
            regexes==[] || all(s <- regexes, regexp(_) := s), // Explicity empty domain check to deal with Rascal bug
            acceptsEmpty((regexToPSNFA(r) | concatPSNFA(it, regexToPSNFA(f)) | regexp(f) <- regexes))
        ) {
            // For each of the encountered regexes, make a production where this regex is not nullable
            allRegexes = [r] + [rf | regexp(rf) <- regexes];
            for(i <- [0..size(allRegexes)]) {
                newRegexes = allRegexes;
                <rMain, _, _> = factorOutEmpty(newRegexes[i]);
                if(rMain != never()) {
                    newRegexes[i] = rMain;
                    newParts = [regexp(nr) | nr <- newRegexes] + [symRef, *rest];
                    out += convProd(lDef, newParts);
                }
            }

            // Consider the case where all regexes are nullable
            parts = rest;
        }

        if(parts != [])
            out += convProd(lDef, parts);
    }

    return out;
}