module conversion::util::meta::wrapRegexScopes

import Scope;
import regex::Tags;
import regex::RegexTypes;
import regex::RegexCache;
import regex::RegexProperties;

@doc {
    Wraps the given regular expresion in the given scope
}
Regex wrapRegexScopes(Regex regex, ScopeList scopeList) {
    if(scopeList==[]) return regex;
    Scopes scopes = toScopes(scopeList);
    Regex prefixScopes(Regex regex) {
        if(!containsScopes(regex)) return regex;        
        switch(regex) {
            case mark(tags, r): return mark({
                scopeTag(s) := t ? scopeTag(concat(scopes, s)) : t | t <- tags
            }, prefixScopes(r));
            case lookahead(r, la): return lookahead(prefixScopes(r), la);
            case \negative-lookahead(r, la): return \negative-lookahead(prefixScopes(r), la);
            case lookbehind(r, lb): return lookbehind(prefixScopes(r), lb);
            case \negative-lookbehind(r, lb): return \negative-lookbehind(prefixScopes(r), lb);
            case subtract(r, re): return subtract(prefixScopes(r), re);
            case concatenation(h, t): return concatenation(prefixScopes(h), prefixScopes(t));
            case alternation(o1, o2): return alternation(prefixScopes(o1), prefixScopes(o2));
            case \multi-iteration(r): return \multi-iteration(prefixScopes(r));
            case meta(r, m:metaCache(_, _)): return prefixScopes(r);  // Note that we remove the internal caches, since they are no longer correct and we can't use them anymore
            case meta(r, m): return meta(prefixScopes(r), m);
            default: {
                println("Error: missed a case in wrapScopes: <regex>");
                return regex;
            }
        }
    }


    // This only prefixes the regex, not the cached PSNFAs
    prefixedRegexScopes = prefixScopes(regex);
    withNewScopes = mark({scopeTag(scopes)}, prefixedRegexScopes);

    // Recalculate the cache
    return getCachedRegex(withNewScopes);
}
