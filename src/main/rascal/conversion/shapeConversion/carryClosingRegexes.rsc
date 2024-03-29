module conversion::shapeConversion::carryClosingRegexes

import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::shapeConversion::defineSequence;
import conversion::util::makeLookahead;
import Warning;
import Logging;
import TestConfig;

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
] carryClosingRegexes(set[ConvProd] prods, ConversionGrammar grammar, TestConfig testConfig) {
    testConfig.log(ProgressDetailed(), "carrying closing expressions");
    set[ConvProd] out = {};

    list[Warning] warnings = [];
    for(p:convProd(lDef, parts) <- prods) {
        if([s, ref(sym, scopes, sources), regexp(r), e] := parts) {
            // TODO: strip empty word matching from `r` if it did

            rla = makeLookahead(r);
            <nWarnings, rlaSym, grammar> = defineSequence([regexp(rla)], p, grammar, testConfig);
            warnings += nWarnings;
            
            parts = [s, ref(closed(sym, rlaSym), scopes, sources), regexp(r), e];
        }

        out += convProd(lDef, parts);
    }

    return <warnings, out, grammar>;
}