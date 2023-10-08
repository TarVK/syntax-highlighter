module conversion::shapeConversion::splitSequences

import Relation;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::shapeConversion::defineSequence;
import conversion::util::meta::LabelTools;
import conversion::util::makeLookahead;
import Warning;

@doc {
    Converts a given sequence of 3 symbols, or more than 4 symbols, into a sequence of 4 symbols:
    ```
    A -> X B Y C Z A
    ```
    => 
    ```
    A -> X unionRec(B|convSeq(Y C)) Z A
    ```
    or
    ```
    A -> X Y A
    ```
    => 
    ```
    A -> X unionRec() Y A
    ```
}
tuple[
    list[Warning] warnings,
    set[ConvProd] prods,
    ConversionGrammar grammar
] splitSequences(set[ConvProd] prods, ConversionGrammar grammar) {
    list[Warning] warnings = [];
    set[ConvProd] out = {};

    for(p:convProd(lDef, parts) <- prods) {
        if(
            [f:regexp(_), *rest, s:regexp(la), r:ref(_, _, _)] := parts, 
            [ref(_, _, _)] !:= rest
        ) {
            <nWarnings, seqSym, grammar> = defineSequence(
                rest == [] 
                    ? []
                    : rest + regexp(makeLookahead(la)
            ), p, grammar);
            warnings += nWarnings;
            out += convProd(lDef, [f, ref(seqSym, [], {}), s, r]);
        } else 
            out += p;
    }

    return <warnings, out, grammar>;
}