module conversion::determinism::expandSymbols

import List;
import Map;
import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import regex::Regex;

data DeterminismTag = determinismTag(); // A regex tag used to identify that a lookahead only exists for determinism purposes, not for language correctness

@doc {
    Expands the given parts into `length` number of concatenated regular expressions if possible
}
Maybe[Regex] expandSymbolsToRegex(list[ConvSymbol] parts, ConversionGrammar grammar, int length) {
    seqOptions = expandSymbols(parts, grammar, length);

    Maybe[Regex] combineRegex(set[list[Regex]] seqOptions) {
        if(size(seqOptions)==0) return nothing();
        if([] in seqOptions) return nothing(); // If there's an empty option, all other lookahead alternations become redudant, since the empty will match those too.

        map[Regex, set[list[Regex]]] index = ();
        for([first, *rest] <- seqOptions) {
            if(first notin index) index[first] = {};
            index[first] += rest;
        }

        list[Regex] options = [];
        for(first <- index) {
            if(just(s) := combineRegex(index[first])) 
                options += concatenation(first, s);
            else 
                options += first;
        }

        // The below code does the same as this: 
        // return just(reduceAlternation(Regex::alternation(options)));
        // But this is erroring for seemingly no reason and I don't want to deal with this Rascal shit right now. 

        if([option] := options) return just(option);
        if([opt1, opt2, *rest] := options) return just((alternation(opt1, opt2) | alternation(it, part) | part <- rest));
        return nothing();
    }

    return combineRegex(seqOptions);
}

set[list[Regex]] expandSymbols(list[ConvSymbol] parts, ConversionGrammar grammar, int length) {
    map[Symbol, bool] nullableMap = ();
    bool isNullable(Symbol sym) {
        sym = getWithoutLabel(sym);
        if (sym in nullableMap) return nullableMap[sym];

        res = false;
        nullableMap[sym] = res; // Prevent loops caused by (A -> B; B -> A) productions
        prods = grammar.productions[sym];
        if (convProd(_, [], _) <- prods) res = true;
        else res = any(convProd(_, [symb(s, _)], _) <- prods, isNullable(s));
        nullableMap[sym] = res;
        return res;
    }

    set[list[ConvSymbol]] seqQueue = {};
    set[list[ConvSymbol]] encountered = {};
    set[list[Regex]] out = {};
    void addToQueue(list[ConvSymbol] seq) {
        if (seq in encountered) return;
        encountered += seq;
        cutSeq = seq[..length];
        encountered += cutSeq;

        // Recursively consider all cases where a symbol may be removed, before cutting off the suffix outside of the length
        if([*p, symb(sym, _), *s] := seq, isNullable(sym)) 
            addToQueue([*p, *s]);

        seqQueue += cutSeq;
        if(size(cutSeq) == 0 || all(p <- cutSeq, regexp(_) := p)) 
            out += [r | regexp(r) <- cutSeq];
    }
    addToQueue(parts);

    while(size(seqQueue) > 0) {
        <sequence, seqQueue> = takeOneFrom(seqQueue);

        if([*p, symb(sym, _), *s] := sequence){
            for(convProd(_, subParts, _) <- grammar.productions[getWithoutLabel(sym)]) {
                if(size(subParts) == 0) continue; // This already has been considered during add to queue, before cutting off the tail
                
                addToQueue([*p, *subParts, *s]);
            }
        }
    }

    return out;
}