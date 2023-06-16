module conversionGrammar::RegexConversion

import Set;
import Relation;
import Map;
import List;
import IO;

import conversionGrammar::ConversionGrammar;
import regex::Regex;


@doc {
    Combines productions into regular expressions in the given grammar
}
ConversionGrammar convertToRegularExpressions(ConversionGrammar grammar) {
    productions = index(grammar.productions);
    for(nonTerminal <- productions) {
        nonTerminalProductions = productions[nonTerminal];
        combined = combineUnions(nonTerminalProductions);
        if(size(combined) < size(nonTerminalProductions)) {
            productions[nonTerminal] = combined;
        }
    }

    return convGrammar(grammar.\start, toRel(productions));
}

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

    This is done exhasutively for this production set.
}
set[ConvProd] combineUnions(set[ConvProd] productions) = combineUnions(productions, 0);

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

    This is done exhasutively for this production set.
    Assumes the symbols up to and excluding startIndex to be identical between all productions
}
set[ConvProd] combineUnions(set[ConvProd] productions, int startIndex) {
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
                    if(!equals(prodI, prodJ, startIndex+1)) continue;

                    combine += <symbJ, prodJ>;
                    indexed -= <symbJ, prodJ>;
                    continue group;
                }
            }

            if(size(combine) > 1 && convProd(def, pb, _) := prodI) {
                indexed -= <symbI, prodI>;
                combinedSymbol = regexp(alternation([r | <regexp(r), _> <- combine]));
                sources = {*s | <_, convProd(_, _, s)> <- combine};
                pb[startIndex] = combinedSymbol;
                indexed += <combinedSymbol, convProd(def, pb, sources)>;
            }
        }
    }

    // Continue combining groups for the next symbol
    newSymbols = {s | s <- indexed<0>};
    for(symb <- newSymbols) {
        prods = indexed[symb];
        if(size(prods) == 1) out += prods;
        else out += combineUnions(prods, startIndex+1);
    }

    return out;
}

bool equals(a:convProd(_, pa, _), b:convProd(_, pb, _), int index) {
    if(size(pa) != size(pb)) return false;
    for(i <- [index..size(pa)])
        if(pa[i] != pb[i]) return false;
    return true;
}