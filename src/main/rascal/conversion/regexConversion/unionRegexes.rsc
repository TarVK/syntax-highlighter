module conversion::regexConversion::unionRegexes

import Set;
import Relation;
import Map;
import List;
import IO;

import util::List;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::liftScopes;
import conversion::regexConversion::concatenateRegexes;
import conversion::util::meta::LabelTools;
import conversion::util::equality::ProdEquivalence;
import regex::RegexCache;
import regex::Regex;
import regex::regexToPSNFA;
import regex::PSNFACombinators;
import regex::PSNFATools;

@doc {
    Tries to apply the union rule:
    ```
    A -> x X y          
    A -> x Y y          
    ```
    => {Union}
    ```
    A -> x (X | Y) y
    ```

    Also tries to consider implicit regular expressions:
    ```
    A -> x X y          
    A -> x y          
    ```
    => {Union}
    ```
    A -> x (X | ) y
    ```


    Internally applies the rules:
    - Concatenation
    - Scope lifting

    This is done exhasutively for this production set.
}
set[ConvProd] unionRegexes(set[ConvProd] productions) = concatenateRegexes(unionRegexes(productions, 0));

@doc {
    Tries to apply the union rule:
    ```
    A -> x X y          
    A -> x Y y          
    ```
    => {Union}
    ```
    A -> x (X | Y) y
    ```
    
    Also tries to consider implicit regular expressions:
    ```
    A -> x X y          
    A -> x y          
    ```
    => {Union}
    ```
    A -> x (X | ) y
    ```

    Internally applies the rules:
    - Scope lifting

    This is done exhasutively for this production set.
    Assumes the symbols up to and excluding startIndex to be identical between all input productions
}
set[ConvProd] unionRegexes(set[ConvProd] productions, int startIndex) {
    set[ConvProd] out = {};

    // Index all productions on their start symbol, and add prods with no more start symbols to the output
    // This considers the fact that syntactically different regular expressions may define the same language
    rel[ConvSymbol, ConvProd] indexed = {};
    void addToIndex(p:convProd(_, parts)) {
        if(size(parts) <= startIndex){
            out += p;
            return;
        }

        indexSym = getEquivalenceSymbol(parts[startIndex]);
        indexed += <indexSym, p>;    
    }
    for(prod <- productions) 
        addToIndex(prod);

    emptySym = regexp(getCachedRegex(empty()));

    // For each index group, check overlap with a production in another group
    symbols = [s | s <- indexed<0>];
    for(i <- [0..size(symbols)]) {
        symbI = symbols[i];
        if(!(regexNfa(_) := symbI)) continue;

        prodsI = indexed[symbI];
        for(prodI <- prodsI) {
            set[ConvProd] combine = {prodI};

            // Check whether there are productions where everything but the first symbol equals, in order to union on the first symbol
            group: for(j <- [i+1..size(symbols)]) {
                symbJ = symbols[j];
                if(!(regexNfa(_) := symbJ)) continue group;

                prodsJ = indexed[symbJ];

                for(prodJ <- prodsJ) {
                    prodsRemaindersEqual = equalsAfter(prodI.parts, prodJ.parts, startIndex+1);
                    if(!prodsRemaindersEqual) continue;

                    combine += prodJ;
                    indexed -= <symbJ, prodJ>;
                    continue group;
                }
            }

            // Check whether there are productions where skipping the first symbol makes the rest match, in order to union an empty match
            prodILength = size(prodI.parts);
            for(prodJ:convProd(lDef, parts) <- productions, prodJ != prodI){
                if(size(parts)+1 != prodILength) continue;

                newParts = insertAt(parts, startIndex, emptySym); // Pretend there was an empty regex in there
                prodsRemaindersEqual = equalsAfter(prodI.parts, newParts, startIndex+1);
                if(!prodsRemaindersEqual) continue;

                augmented = convProd(lDef, newParts);
                combine += augmented;
                if(size(parts)>startIndex) 
                    indexed -= <parts[startIndex], prodJ>;
                else
                    out -= prodJ;
            }

            // Perform the unioning
            if(size(combine) > 1 && convProd(def, pb) := prodI) {
                indexed -= <symbI, prodI>;

                regexes = [r | convProd(_, parts) <- combine, regexp(r) := parts[startIndex]];
                combinedRegex = liftScopes(reduceAlternation(alternation(regexes)));
                combinedSymbol = regexp(combinedRegex);

                pb[startIndex] = combinedSymbol;

                labeledDef = combineLabels(def, {sym | convProd(sym, _) <- combine});
                addToIndex(convProd(labeledDef, pb));
            }
        }
    }

    // Continue combining groups for the next symbol
    newSymbols = indexed<0>;
    for(symb <- newSymbols) {
        prods = indexed[symb];
        if(size(prods) == 1) out += prods;
        else out += unionRegexes(prods, startIndex+1);
    }

    return out;
}

@doc {
    Checks whether two productions define the same language/tokenization from the given index forward
}
bool equalsAfter(list[ConvSymbol] pa, list[ConvSymbol] pb, int index) {
    if(size(pa) != size(pb)) return false;

    for(i <- [index..size(pa)]) {
        sa = pa[i];
        sb = pb[i];
        if(equals(sa, sb)) continue;

        return false;
    }

    return true;
}