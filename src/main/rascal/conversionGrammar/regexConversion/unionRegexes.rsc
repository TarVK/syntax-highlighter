module conversionGrammar::regexConversion::unionRegexes

import Set;
import Relation;
import Map;
import List;
import IO;

import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::liftScopes;
import conversionGrammar::regexConversion::concatenateRegexes;
import regex::RegexToPSNFA;
import regex::Regex;
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

    Internally applies the rules:
    - Scope lifting

    This is done exhasutively for this production set.
    Assumes the symbols up to and excluding startIndex to be identical between all productions
}
set[ConvProd] unionRegexes(set[ConvProd] productions, int startIndex) {
    set[ConvProd] out = {};

    // Index all productions on their start symbol, and add prods with no more start symbols to the output
    rel[ConvSymbol, ConvProd] indexed = {};
    for(p:convProd(symb, parts, sources) <- productions) {
        if(size(parts) <= startIndex){
            out += p;
            continue;
        }

        indexed += <parts[startIndex], p>;        
    }

    // For each index group, check overlap with a production in another group
    symbols = [s | s <- indexed<0>];
    for(i <- [0..size(symbols)]) {
        symbI = symbols[i];
        if(!(regexp(_) := symbI)) continue;

        prodsI = indexed[symbI];
        for(prodI <- prodsI) {
            set[tuple[ConvSymbol, ConvProd]] combine = {<symbI, prodI>};

            group: for(j <- [i+1..size(symbols)]) {
                symbJ = symbols[j];
                if(!(regexp(_) := symbJ)) continue group;

                prodsJ = indexed[symbJ];
                for(prodJ <- prodsJ) {
                    prodsRemaindersEqual = equalsAfter(prodI, prodJ, startIndex+1);
                    if(!prodsRemaindersEqual) continue;

                    combine += <symbJ, prodJ>;
                    indexed -= <symbJ, prodJ>;
                    continue group;
                }
            }

            if(size(combine) > 1 && convProd(def, pb, _) := prodI) {
                indexed -= <symbI, prodI>;

                combinedRegex = liftScopes(
                    reduceAlternation(alternation([r | <regexp(r), _> <- combine]))
                );
                combinedSymbol = regexp(combinedRegex);

                sources = {*s | <_, convProd(_, _, s)> <- combine};
                pb[startIndex] = combinedSymbol;

                // Find an equivalent regex (maybe not syntactically) to index the prod under
                indexSym = combinedSymbol;
                indexedSymbols = indexed<0>;
                if(!(combinedSymbol in indexedSymbols)) {
                    for(symb:regexp(symbRegex) <- indexedSymbols) {
                        combinedRegexPsnfa = regexToPSNFA(combinedRegex);
                        symbPsnfa = regexToPSNFA(symbRegex);
                        if(equals(symbPsnfa, combinedRegexPsnfa)) {
                            indexSym = symb;
                            break;
                        }
                    }                    
                }
                indexed += <indexSym, convProd(def, pb, sources)>;
            }
        }
    }

    // Continue combining groups for the next symbol
    newSymbols = {s | s <- indexed<0>};
    for(symb <- newSymbols) {
        prods = indexed[symb];
        if(size(prods) == 1) out += prods;
        else out += unionRegexes(prods, startIndex+1);
    }

    return out;
}