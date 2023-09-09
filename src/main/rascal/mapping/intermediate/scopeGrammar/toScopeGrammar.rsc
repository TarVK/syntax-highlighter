module mapping::intermediate::scopeGrammar::toScopeGrammar

import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::intermediate::scopeGrammar::cleanupRegex;
import mapping::intermediate::scopeGrammar::extractRegexScopes;
import mapping::intermediate::scopeGrammar::removeRegexSubtraction;
import mapping::intermediate::scopeGrammar::splitRegexLookarounds;
import conversion::util::RegexCache;
import regex::Regex;
import regex::PSNFA;
import regex::PSNFATools;
import regex::NFASimplification;
import regex::PSNFACombinators;
import conversion::util::makeLookahead;
import Warning;
import Scope;

data Warning = unresolvabledSubtraction(Regex regex, NFA[State] delta, ConvProd production);

@doc {
    Converts a conversion grammar to a scope grammar. 
    Assumes that every production in the conversion grammar has the correct format, meaning that every production must have one of the following shapes:
    ```
    A -> 
    A -> X A
    A -> X B Y A
    ```
}
WithWarnings[ScopeGrammar] toScopeGrammar(ConversionGrammar grammar) {
    ScopeProductions prods = ();

    list[Warning] warnings = [];

    set[str] textSymbols = {};
    SymbolMap symMapping = ();
    TokenCache tokenCache = ();
    ScopeCache scopeCache = ();

    for(sym <- grammar.productions<0>) {
        symInpProds = grammar.productions[sym];
        <textSym, symMapping, textSymbols> = getSymbolString(sym, symMapping, textSymbols);

        list[ScopeProd] symProds = [];
        prods[textSym] = symProds;

        for(prod:convProd(_, [regexp(r), symb(_, _)], _) <- symInpProds) {
            <prodSym, newWarnings, tokenCache, prods, textSymbols> 
                = defineTokenProd(r, tokenCache, prods, prod, textSymbols);
            symProds += inclusion(prodSym);
            warnings += newWarnings;
        }

        for(prod:convProd(_, [regexp(open), symb(ref, scopes), regexp(close), symb(_, _)], _) <- symInpProds) {
            <textRef, symMapping, textSymbols> = getSymbolString(ref, symMapping, textSymbols);
            <prodSym, newWarnings, scopeCache, prods, textSymbols> 
                = defineScopeProd(open, textRef, scopes, close, scopeCache, prods, prod, textSymbols);
            symProds += inclusion(prodSym);
            warnings += newWarnings;
        }

        prods[textSym] = symProds;
    }


    return <warnings, scopeGrammar(getSymbolString(grammar.\start, symMapping, textSymbols)<0>, prods)>;
}

alias SymbolMap = map[Symbol, str];

alias TokenCache = map[Regex, str];
tuple[str, list[Warning], TokenCache, ScopeProductions, set[str]] defineTokenProd(
    Regex regex, 
    TokenCache tokenCache,
    ScopeProductions prods, 
    ConvProd prod,
    set[str] textSymbols
) {
    regexCacheless = removeRegexCache(regex);
    if(regexCacheless in tokenCache) return <tokenCache[regexCacheless], [], tokenCache, prods, textSymbols>;

    <textSym, textSymbols> = createUniqueSymbol(just(text) := getLabel(prod) ? text : "T", textSymbols);
    tokenCache[regexCacheless] = textSym;

    <warnings, scopedRegex> = convertRegex(regex, prod);
    prods[textSym] = [tokenProd(scopedRegex, sources=prod.sources)];

    return <textSym, warnings, tokenCache, prods, textSymbols>;
}

alias ScopeCache = map[tuple[Regex, str, Scopes, Regex], str];
tuple[str, list[Warning], ScopeCache, ScopeProductions, set[str]] defineScopeProd(
    Regex open, 
    str ref,
    Scopes scopes,
    Regex close,
    ScopeCache scopeCache,
    ScopeProductions prods, 
    ConvProd prod,
    set[str] textSymbols
) {
    openCacheless = removeRegexCache(open);
    closeCacheless = removeRegexCache(close);

    key = <openCacheless, ref, scopes, closeCacheless>;
    if(key in scopeCache) return <scopeCache[key], [], scopeCache, prods, textSymbols>;

    <textSym, textSymbols> = createUniqueSymbol(just(text) := getLabel(prod) ? text : "S", textSymbols);
    scopeCache[key] = textSym;

    Scope scope;
    if([first, second, *rest] := scopes) {
        // If we want a secuence of scopes, we simply use lookaheads to open a sequence of symbols
        scope = first;
        <ref, _, scopeCache, prods> = defineScopeProd(
            open, 
            ref, 
            [second, *rest], 
            makeLookahead(close, false), 
            prods, 
            scopeCache,
            prod
        );
        open = makeLookahead(open, false);
    } else if([first] := scopes) 
        scope = first;
    else if([] := scopes)
        scope = [];

    <openWarnings, openScoped> = convertRegex(open, prod);
    <closeWarnings, closeScoped> = convertRegex(close, prod);
    prods[textSym] = [scopeProd(openScoped, <ref, scope>, closeScoped, sources=prod.sources)];

    return <textSym, openWarnings+closeWarnings, scopeCache, prods, textSymbols>;
}

WithWarnings[tuple[Regex, list[Scope]]] convertRegex(Regex regex, ConvProd prod) {
    <subtractionlessRegex, isEqual> = removeRegexSubtraction(regex);
    list[Warning] warnings = [];
    if(!isEqual) {
        delta = differencePSNFA(regexToPSNFA(regex), regexToPSNFA(subtractionlessRegex));
        minimizedDelta = relabelSetPSNFA(minimize(delta));
        warnings = [unresolvabledSubtraction(regex, minimizedDelta, prod)];
    }
    emptyLookarounds = splitRegexLookarounds(removeRegexCache(subtractionlessRegex));
    improvedRegex = cleanupRegex(emptyLookarounds);
    return <warnings, extractRegexScopes(improvedRegex)>;
}


tuple[str name, set[str] taken] createUniqueSymbol(str name, set[str] taken) {
    if(name in taken) {
        int i = 1;
        while("<name><i>" in taken) i+=1;
        name = "<name><i>";
    }

    return <name, taken + name>;
}

tuple[str name, SymbolMap symbolMap, set[str] textSymbols] getSymbolString(
    Symbol sym, 
    SymbolMap symbolMap, 
    set[str] textSymbols
) {
    sym = getWithoutLabel(sym);
    if(sym in symbolMap) return <symbolMap[sym], symbolMap, textSymbols>;

    str text = "G";
    switch(sym) {
        case sort(t): text = t;
        case lex(t): text = "L<t>";
        case layouts(t): text = "W<t>";
        case keywords(t): text = "K<t>";
    }

    <labelText, textSymbols> = createUniqueSymbol(text, textSymbols);
    symbolMap[sym] = labelText;
    return <labelText, symbolMap, textSymbols>;
}