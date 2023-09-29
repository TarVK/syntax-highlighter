module conversion::shapeConversion::defineUnion

import IO;
import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::Alias;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::equality::deduplicateProds;
import conversion::util::Alias;
import conversion::util::meta::LabelTools;
import regex::PSNFA;
import regex::RegexTypes;
import regex::regexToPSNFA;

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
tuple[
    set[ConvProd] prods,
    bool isAlias
] defineUnion(u:unionRec(syms, closing), ConversionGrammar grammar) {
    if(
        isAlias(unionRec(syms, emptyNFA), grammar),
        unionRec(newSyms, _) := followAlias(unionRec(syms, emptyNFA), grammar),
        syms != newSyms
    )
        return <{convProd(u, [ref(unionRec(newSyms, closing), [], {})])}, true>;

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

    return <deduplicateProds(out), false>;
}
NFA[State] emptyNFA = regexToPSNFA(Regex::empty());