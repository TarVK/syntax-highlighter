module conversion::util::equality::deduplicateProds

import IO;
import Set;


import conversion::util::meta::LabelTools;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::equality::ProdEquivalence;
import conversion::util::meta::RegexSources;
import regex::RegexCache;

@doc {
    Gets rid of duplicate productions, and merges sources for these productions
}
set[ConvProd] deduplicateProds(set[ConvProd] prods) {
    rel[list[ConvSymbol], ConvProd] indexed = {};

    if(convProd(lDef, _) <- prods) {
        for(p:convProd(_, parts) <- prods)
            indexed += {<getEquivalenceSymbols(parts), p>};

        for(pl <- indexed<0>) {
            equalProds = indexed[pl];
            if(size(equalProds)==1) continue;

            labels = {l | prod <- equalProds, just(l) := getLabel(prod)};
            newLDef = relabelSymbol(lDef, labels);

            if({firstProd, *restProds} := equalProds) {
                list[ConvSymbol] newParts = [];
                for(i <- [0..size(pl)]) {
                    part = firstProd.parts[i];

                    if(regexp(r) := part) {
                        sources = {*(extractRegexSources(p.parts[i].regex)<0>) | p <- restProds};
                        newParts += regexp(addRegexSources(r, sources));
                    } else if(ref(r, scopes, sources) := part) {
                        newSources = {*p.parts[i].sources | p <- restProds};
                        newParts += ref(r, scopes, sources + newSources);
                    }
                }

                prods -= equalProds;
                prods += convProd(newLDef, newParts);
            }
        }
    }

    return prods;
}