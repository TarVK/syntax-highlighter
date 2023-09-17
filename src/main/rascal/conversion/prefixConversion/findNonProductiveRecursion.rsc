module conversion::prefixConversion::findNonProductiveRecursion

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::Regex;
import regex::RegexTypes;
import regex::RegexCache;
import regex::RegexToPSNFA;
import regex::PSNFATools;


/*
  Find loops in the grammar
*/
alias EmptyPath = list[tuple[
    ConvProd production, 
    int recIndex
]];

@doc {
    Retrieves all paths that have non-productive left recursion that leads back to the specified symbol.
    This considers both direct left recursion, as well as recursion including nullable expressions.
    E.g. it detects loops for `A` in the following scenarios:
    ```
    A -> B
    B -> A
    ```
    ```
    A -> /$e|a/ B
    B -> /$e|b/ A
    ```
    ```
    A -> /$e>a/ B
    B -> /$e>a/ A
    ```
    While knowing the following does not contain a loop:
    ```
    A -> /$e>a/ B
    B -> /$e>b/ A
    ```

    It assumes all non-terminals to be nullable
}
set[EmptyPath] findNonProductiveRecursion(Symbol sym, ProdMap prods)
    = findNonProductiveRecursion(sym, emptyPSNFA(), [], prods);
set[EmptyPath] findNonProductiveRecursion(Symbol sym, NFA[State] emptyPrefix, EmptyPath path, ProdMap prods) {
    // If we reached a loop while still not being forced to consume anything, output the path
    if([<convProd(lDef, _), _>, *_] := path, getWithoutLabel(lDef) == sym)
        return {path};

    if(<convProd(lDef, _), _> <- path, getWithoutLabel(lDef) == sym)
        return {}; // We encounter a loop so we want to stop recursion, but the first element on the path isn't involved in this loop

    set[EmptyPath] paths = {};
    if(sym in prods) {
        for(p:convProd(_, parts) <- prods[sym]) {
            newEmptyPrefix = emptyPrefix;

            int index = 0;
            while([first, *rest] := parts) {
                if(regexp(r) := first) {
                    if(!acceptsEmpty(r)) break; // If the first regex doesn't accept the empty string, there's no remaining empty cycle

                    newEmptyPrefix = concatPSNFA(newEmptyPrefix, regexToPSNFA(r)); // By operating direclty on the NFAs, we can skip expensive normalization
                    if(isEmpty(newEmptyPrefix)) break; // If the language of the concatenation becomes empty (due to contradicting restrictions), this can't be matched in a cycle        
                } else if(ref(subSym, _, _) := first) {
                    newPath = [*path, <p, index>];
                    paths += findNonProductiveRecursion(subSym, newEmptyPrefix, newPath, prods);
                }

                parts = rest;
                index += 1;
            }
        }
    }

    return paths;
}