module conversion::shapeConversion::carryClosingRegexes

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::shapeConversion::defineSequence;
import conversion::util::makeLookahead;
import Warning;

@doc {
    For any production of the shape:
    ```
    A -> X B Y C
    ```
    Transforms the production into:
    ```
    A -> X closed(B, convSeq([/>Y/])) Y C
    ```

    Adds convSeq definitions to the output grammar if necessary
}
tuple[
    list[Warning] warnings,
    set[ConvProd] prods,
    ConversionGrammar grammar
] carryClosingRegexes(set[ConvProd] prods, ConversionGrammar grammar) {
    set[ConvProd] out = {};

    list[Warning] warnings = [];
    for(p:convProd(lDef, parts) <- prods) {
        if([s, ref(sym, scopes, sources), regexp(r), e] := parts) {
            rla = makeLookahead(r);
            <nWarnings, rlaSym, grammar> = defineSequence([regexp(rla)], p, grammar);
            warnings += nWarnings;
            
            parts = [s, ref(closed(sym, rlaSym), scopes, sources), regexp(r), e];
        }

        out += convProd(lDef, parts);
    }

    return <warnings, out, grammar>;
}