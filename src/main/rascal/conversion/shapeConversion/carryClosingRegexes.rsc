module conversion::shapeConversion::carryClosingRegexes

import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::shapeConversion::defineSequence;
import conversion::util::BaseNFA;
import conversion::util::makeLookahead;
import regex::PSNFACombinators;
import regex::regexToPSNFA;
import regex::PSNFA;
import regex::RegexTypes;
import Warning;

import testing::util::visualizeGrammars;

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
] carryClosingRegexes(set[ConvProd] prods, ConversionGrammar grammar, bool addSplitInfo) {
    set[ConvProd] out = {};

    list[Warning] warnings = [];
    for(p:convProd(lDef, parts) <- prods) {
        if([s, ref(sym, scopes, sources), regexp(r), e] := parts) {
            rla = makeLookahead(r);
            <nWarnings, rlaSym, grammar> = defineSequence([regexp(rla)], p, grammar);
            warnings += nWarnings;
            
            if(unionRec(u, c) := sym) {
                sym = simplify(
                    unionRec(
                        {sym}, 
                        addSplitInfo ? regexToPSNFA(rla) : emptyNFA
                    ), 
                    grammar
                );
                if(unionRec(_, c2) := sym && c2 == neverNFA) {
                    println(<"DEtect", addSplitInfo, c2>);
                    visualizeGrammars(<unionRec(u, c), c, sym, c2>);
                    throw "shit";
                }
            }
            parts = [s, ref(closed(sym, rlaSym), scopes, sources), regexp(r), e];
        }

        out += convProd(lDef, parts);
    }

    return <warnings, out, grammar>;
}