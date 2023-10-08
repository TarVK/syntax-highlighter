module conversion::shapeConversion::defineUnion

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::equality::deduplicateProds;
import conversion::util::Alias;
import conversion::util::meta::LabelTools;

@doc {
    Retrieves the productions to define the given union symbol:
    for `unionRec(A|B)`, with
    ```
    A -> X A
    A -> Y A
    B -> Z B
    B -> W B
    ```
    we define:
    ```
    unionRec(A|B) -> X A unionRec(A|B)
    unionRec(A|B) -> Y A unionRec(A|B)
    unionRec(A|B) -> Z B unionRec(A|B)
    unionRec(A|B) -> W B unionRec(A|B)
    ```
}
set[ConvProd] defineUnion(u:unionRec(syms), ConversionGrammar grammar) {
    set[ConvProd] out = {};

    for(sym <- syms) {
        baseSym = followAlias(sym, grammar);
        prods = grammar.productions[baseSym];
        for(convProd(lDef, parts) <- prods) {
            parts = followPartsAliases(parts, grammar);
            out += convProd(
                copyLabel(lDef, u), 
                parts == []
                    ? parts
                    : parts + [ref(u, [], {})]
            );
        }
    }

    out += convProd(label("empty", u), []);

    return deduplicateProds(out);
}