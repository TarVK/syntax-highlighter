module conversion::shapeConversion::removeRedundantLookaheads

import Set;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import conversion::util::equality::ProdEquivalence;
import conversion::util::meta::LabelTools;
import conversion::util::meta::extractSources;

@doc {
    Removes redudant lookahead suffixes, e.g.:
    ```
    A -> x B />X/ closed(B, convSeq([/>X/]))
    ```
    => (Broadens to)
    ```
    A -> x closed(B, convSeq([/>X/]))
    ```

    If `ensureCommonSuffix` is set to true, the conversion is only performed if the same lookahead precedes it:
    ```
    A -> x />X/ B />X/ closed(B, convSeq([/>X/]))
    ```
    => (Broadens to)
    ```
    A -> x />X/ closed(B, convSeq([/>X/]))
    ```
}
set[ConvProd] removeRedundantLookaheads(set[ConvProd] prods, bool ensureCommonSuffix) {
    set[ConvProd] out = {};
    for(p:convProd(lDef, parts) <- prods) {
        if(
            [*startP, ref(sym, [], sa), rp:regexp(_), ref(c:closed(sym, convSeq([s])), [], sb)] := parts,
            getEquivalenceSymbol(rp) == getEquivalenceSymbol(s)
        ) {
            if (
                !ensureCommonSuffix
                || (
                    [*_, rp2:regexp(_)] := startP 
                    && getEquivalenceSymbol(rp2) == getEquivalenceSymbol(s)
                )
            ) {    
                newSources = sa + sb + extractSources(rp);
                out += convProd(lDef, [*startP, ref(c, [], newSources)]);
                continue;
            }
        }

        out += p;
    }

    return out;
}