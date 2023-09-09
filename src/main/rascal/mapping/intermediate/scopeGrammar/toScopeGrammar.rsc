module mapping::intermediate::scopeGrammar::toScopeGrammar

import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::intermediate::scopeGrammar::cleanupRegex;
import mapping::intermediate::scopeGrammar::extractRegexScopes;
import mapping::intermediate::scopeGrammar::removeRegexSubtraction;
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
    TokenCache tokenCache = ();
    ScopeCache scopeCache = ();

    for(sym <- grammar.productions<0>) {
        symInpProds = grammar.productions[sym];
        set[ScopeProd] symProds = {};
        prods[sym] = {};

        for(prod:convProd(_, [regexp(r), symb(_, _)], _) <- symInpProds) {
            <prodSym, newWarnings, tokenCache, prods> 
                = defineTokenProd(r, tokenCache, prods, prod);
            symProds += inclusion(prodSym);
            warnings += newWarnings;
        }

        for(prod:convProd(_, [regexp(open), symb(ref, scopes), regexp(close), symb(_, _)], _) <- symInpProds) {
            <prodSym, newWarnings, scopeCache, prods> 
                = defineScopeProd(open, ref, scopes, close, scopeCache, prods, prod);
            symProds += inclusion(prodSym);
            warnings += newWarnings;
        }

        prods[sym] = symProds;
    }

    return <warnings, scopeGrammar(grammar.\start, prods)>;
}

alias TokenCache = map[Regex, Symbol];
tuple[Symbol, list[Warning], TokenCache, ScopeProductions] defineTokenProd(
    Regex regex, 
    TokenCache tokenCache,
    ScopeProductions prods, 
    ConvProd prod
) {
    regexCacheless = removeRegexCache(regex);
    if(regexCacheless in tokenCache) return <tokenCache[regexCacheless], [], tokenCache, prods>;

    str newLabel = just(text) := getLabel(prod) ? text : "t";
    if(sort(newLabel) in prods) {
        int i = 1;
        while(sort("<newLabel><i>") in prods) i+=1;
        newLabel = "<newLabel><i>";
    }

    Symbol sym = sort(newLabel);
    <warnings, scopedRegex> = convertRegex(regex, prod);
    prods[sym] = {tokenProd(scopedRegex, sources=prod.sources)};
    tokenCache[regexCacheless] = sym;

    return <sym, warnings, tokenCache, prods>;
}

alias ScopeCache = map[tuple[Regex, Symbol, Scopes, Regex], Symbol];
tuple[Symbol, list[Warning], ScopeCache, ScopeProductions] defineScopeProd(
    Regex open, 
    Symbol ref,
    Scopes scopes,
    Regex close,
    ScopeCache scopeCache,
    ScopeProductions prods, 
    ConvProd prod
) {
    openCacheless = removeRegexCache(open);
    closeCacheless = removeRegexCache(close);

    key = <openCacheless, getWithoutLabel(ref), scopes, closeCacheless>;
    if(key in scopeCache) return <scopeCache[key], [], scopeCache, prods>;

    str newLabel = just(text) := getLabel(prod) ? text : "s";
    if(sort(newLabel) in prods) {
        int i = 1;
        while(sort("<newLabel><i>") in prods) i+=1;
        newLabel = "<newLabel><i>";
    }

    Symbol sym = sort(newLabel);
    scopeCache[key] = sym;

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
    prods[sym] = {scopeProd(openScoped, <ref, scope>, closeScoped, sources=prod.sources)};

    return <sym, openWarnings+closeWarnings, scopeCache, prods>;
}

WithWarnings[tuple[Regex, list[Scope]]] convertRegex(Regex regex, ConvProd prod) {
    <subtractionlessRegex, isEqual> = removeRegexSubtraction(regex);
    list[Warning] warnings = [];
    if(!isEqual) {
        delta = differencePSNFA(regexToPSNFA(regex), regexToPSNFA(subtractionlessRegex));
        minimizedDelta = relabelSetPSNFA(minimize(delta));
        warnings = [unresolvabledSubtraction(regex, minimizedDelta, prod)];
    }
    improvedRegex = cleanupRegex(removeRegexCache(subtractionlessRegex));
    return <warnings, extractRegexScopes(improvedRegex)>;
}