module conversion::shapeConversion::checkLeftRecursion

import Relation;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::prefixConversion::findNonProductiveRecursion;
import conversion::util::meta::LabelTools;
import regex::RegexTypes;
import regex::PSNFATypes;
import regex::PSNFACombinators;
import regex::RegexCache;
import regex::RegexTransformations;
import Warning;

@doc {
    Detects left recursion and removes it:
    ```
    A -> /(>X)/ B x
    B -> /(>X)/ A y
    ```
    => {Not a safe transformation, generates warnings/errors}
    ```
    A -> /$0(>X)/ B x
    B -> /(>X)/ A y
    ```
}
WithWarnings[set[ConvProd]] checkLeftRecursion(set[ConvProd] prods, ConversionGrammar grammar) {
    list[Warning] warnings = [];
    set[ConvProd] out = {};

    if(convProd(lDef, _) <- prods) {
        sym = getWithoutLabel(lDef);

        // Obtain the empty paths starting at this symbol
        prodMap = Relation::index(grammar.productions);
        prodMap[sym] = prods;

        emptyPaths = findNonProductiveRecursion(sym, prodMap);
        map[ConvProd, set[EmptyPath]] problematicProds 
            = Relation::index({<p, path> | path:[<p, _>, *_] <- emptyPaths});

        // Make the empty paths unreachable and generate warnings
        for(prod <- prods) {
            if(prod in problematicProds) {
                emptyPaths = problematicProds[prod];
                if(convProd(lDef2, [regexp(r), *parts]) := prod) {
                    <rMain, _, _> = factorOutEmpty(r);
                    if(rMain == never()) rMain = getCachedRegex(concatenation(rMain, r)); // Only to keep some more info about the original regex, to aid in debugging later

                    out += convProd(lDef2, [regexp(rMain), *parts]);
                    warnings += unresolvableLeftRecursiveLoop(emptyPaths, prod);
                }
            } else {
                out += prod;
            }
        }
    }

    return <warnings, out>;
}