module conversion::shapeConversion::defineClosing

import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::equality::deduplicateProds;
import conversion::util::Alias;
import conversion::util::meta::LabelTools;

@doc {
    Retrieves the productions to define the given closing symbol:
    for `closed(A, B)`, with
    ```
    A -> X A
    A -> Y A
    B -> Z B
    B -> W B
    ```
    we define:
    ```
    closed(A, B) -> X A Z B closed(A, B)
    closed(A, B) -> X A W B closed(A, B)
    closed(A, B) -> Y A Z B closed(A, B)
    closed(A, B) -> Y A W B closed(A, B)
    ```
}
set[ConvProd] defineClosing(c:closed(baseSym, closeSym), ConversionGrammar grammar) {
    baseSym = followAlias(baseSym, grammar);
    closeSym = followAlias(closeSym, grammar);
    baseProds = grammar.productions[baseSym];
    closeProds = grammar.productions[closeSym];

    set[ConvProd] out = {};
    for(
        convProd(baseLDef, baseParts) <- baseProds,
        convProd(closeLDef, closeParts) <- closeProds
    ) {
        labels = ((label(bl, _) := baseLDef) ? {bl} : {}) + ((label(cl, _) := closeLDef) ? {cl} : {});

        baseParts = followPartsAliases(baseParts, grammar);
        closeParts = followPartsAliases(closeParts, grammar);
        out += convProd(relabelSymbol(c, labels), baseParts + closeParts + [ref(c, [], {})]);
    }

    out += convProd(label("empty", c), []);

    return deduplicateProds(out);
}