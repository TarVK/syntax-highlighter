module conversion::baseConversion::carryClosingRegexes

import util::Maybe;
import Set;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::customSymbols;
import conversion::util::Alias;
import conversion::util::makeLookahead;
import conversion::util::RegexCache;

@doc {
    Carries all the closing regexes, such that we exit out of nested recursions when needed.
    E.g.
    ```
    A -> X B Y A
    B -> Z C
    ```
    =>
    ```
    A -> X B_Y Y A
    B_Y -> Z C (>Y) B_Y
    ```
}
ConversionGrammar carryClosingRegexes(ConversionGrammar grammar)
    = carryClosingRegexes(grammar, grammar.productions<0>);
ConversionGrammar carryClosingRegexes(ConversionGrammar grammar, set[Symbol] symbols) {
    while(size(symbols) > 0) {
        set[Symbol] newlyDefined = {};
        for(sym <- symbols) {
            <newlyDefinedForSym, grammar> = carryClosingRegexes(sym, grammar);
            newlyDefined += newlyDefinedForSym;
        }

        symbols = newlyDefined;
    }

    return grammar;
}

tuple[set[Symbol], ConversionGrammar] carryClosingRegexes(Symbol sym, ConversionGrammar grammar) {
    set[Symbol] defined = {};
    for(prod:convProd(_, parts, _) <- grammar.productions[sym]) {
        <newDefined, grammar> = carryClosingRegexes(prod, grammar);
        defined += newDefined;
    }

    return <defined, grammar>;
}

tuple[set[Symbol], ConversionGrammar] carryClosingRegexes(prod:convProd(lDef, _, _), ConversionGrammar grammar) {
    if(just(<newlyDefined, newProd, newGrammar>) := getCarriedClosingRegexes(prod, grammar)) {
        pureDef = getWithoutLabel(lDef);
        newGrammar.productions -= {<pureDef, prod>};
        newGrammar.productions += {<pureDef, newProd>};
        println("Carried closings");
        return <newlyDefined, newGrammar>;
    }

    return <{}, grammar>;
}

Maybe[tuple[set[Symbol], ConvProd, ConversionGrammar]] getCarriedClosingRegexes(prod:convProd(lDef, parts, sources), ConversionGrammar grammar) {
    bool changed = false;
    set[Symbol] newlyDefined = {};
    
    while(
        [*prefixParts, symb(sym, scopes), regexp(r), *suffixParts] := parts,
        closedBy(_, _) !:= sym || (closedBy(_, closing) := sym && removeRegexCache(r) != closing)
    ) {
        <newlyDefinedForSym, newSym, grammar> 
            = defineClosedBy(getWithoutLabel(sym), r, convProdSource(prod), grammar);
        newlyDefined += newlyDefinedForSym;
        parts = [*prefixParts, symb(copyLabel(sym, newSym), scopes), regexp(r), *suffixParts];
        changed = true;
    }
    
    if(!changed) return nothing();
    
    return just(<newlyDefined, convProd(lDef, parts, sources), grammar>);
}


tuple[set[Symbol], Symbol, ConversionGrammar] defineClosedBy(
    Symbol sym, 
    Regex closer, 
    SourceProd closerSource, 
    ConversionGrammar grammar
) {
    cachelessCloser = removeRegexCache(closer);
    if(lookahead(empty(), woLookahead) := cachelessCloser) cachelessCloser = woLookahead;
    closerSym = closedBy(sym, cachelessCloser);

    // Check if already defined
    if(size(grammar.productions[closerSym])>0) 
        return <{}, closerSym, grammar>;

    // Check if the closing regex makes a difference, otherwise simply alias
    prods = grammar.productions[sym];
    requiresClosing = any(convProd(_, [*_, symb(rec, scopes)], _) <- prods, 
        followAlias(rec, grammar) != sym || scopes != []);
    if(!requiresClosing) {
        grammar.productions += {<closerSym, convProd(closerSym, [symb(sym, [])], {})>};
        return <{}, closerSym, grammar>;
    }

    // Check if the symbol is an alias to another symbol, and if so create an alias with closer
    if({convProd(lDef, [symb(ref, [])], sources)} := prods) {
        <newlyDefined, refClosing, grammar> = defineClosedBy(ref, closer, closerSource, grammar);
        grammar.productions += {<
            closerSym, 
            convProd(
                copyLabel(lDef, closerSym), 
                [symb(refClosing, [])],
                {*sources, closerSource}
            )
        >};
        return <newlyDefined + closerSym, closerSym, grammar>;
    }

    // Otherwise define the new symbol with closing regexes
    closerLA = makeLookahead(closer);
    for(convProd(lDef, parts, sources) <- prods) {
        if(
            [*prefixParts, symb(rec, scopes)] := parts,
            followAlias(rec, grammar) != sym || scopes != []
        ) {
            grammar.productions += {<
                closerSym, 
                convProd(
                    copyLabel(lDef, closerSym), 
                    [*prefixParts, symb(rec, scopes), regexp(closerLA), symb(closerSym, [])],
                    {*sources, closerSource}
                )
            >};
        } else if ([*prefixParts, symb(_, _)] := parts) {
            grammar.productions += {<
                closerSym, 
                convProd(
                    copyLabel(lDef, closerSym), 
                    [*prefixParts, symb(closerSym, [])],
                    sources
                )
            >};
        } else {
            grammar.productions += {<
                closerSym, 
                convProd(copyLabel(lDef, closerSym), parts, sources)
            >};
        }
    }

    return <{closerSym}, closerSym, grammar>;
}