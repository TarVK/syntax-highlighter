module conversion::util::meta::applyScopesAndSources

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::wrapRegexScopes;
import conversion::util::meta::RegexSources;
import regex::RegexTypes;
import regex::RegexCache;
import Scope;

@doc {
    Applies the given scopes and sources to a given symbol. 

    Expects the given symbol to either be a regular expression, or a reference to a non-terminal
}
ConvSymbol applyScopesAndSources(ConvSymbol sym, ScopeList newScopes, set[SourceProd] newSources) {
    switch(sym) {
        case ref(s, scopes, sources):
            return ref(s, newScopes+scopes, sources+newSources);
        case regexp(r):{
            if(newSources!={}) r = addRegexSources(r, newSources);
            if(newScopes!=[]) r = wrapRegexScopes(r, newScopes);
            return regexp(getCachedRegex(r));
        } 
        case delete(f, d): return delete(
            applyScopesAndSources(f, newScopes, newSources), 
            applyScopesAndSources(d, [], newSources));
        case follow(s, f): return follow(
            applyScopesAndSources(s, newScopes, newSources), 
            applyScopesAndSources(f, [], newSources));
        case notFollow(s, f): return notFollow(
            applyScopesAndSources(s, newScopes, newSources), 
            applyScopesAndSources(f, [], newSources));
        case precede(s, p): return precede(
            applyScopesAndSources(s, newScopes, newSources), 
            applyScopesAndSources(p, [], newSources));
        case notFPrecede(s, p): return notPrecede(
            applyScopesAndSources(s, newScopes, newSources), 
            applyScopesAndSources(p, [], newSources));
        case atEndOfLine(s): return atEndOfLine(
            applyScopesAndSources(s, newScopes, newSources));
        case atStartOfLine(s): return atStartOfLine(
            applyScopesAndSources(s, newScopes, newSources));
    }
    return sym;
}
