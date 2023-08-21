module conversion::util::RegexCache

extend regex::RegexToPSNFA;

import regex::RegexTypes;
import regex::Regex;
import regex::RegexToPSNFA;
import regex::NFA;
import regex::PSNFATypes;
import regex::PSNFACombinators;

// Create a new regex constructor an related functions
data Regex = cached(Regex exp, NFA[State] psnfa, bool hasScope);
str stringify(cached(exp, _, _)) = stringify(exp);
NFA[State] regexToPSNFA(cached(_, psnfa, _)) = psnfa;

@doc {
    Removes all caches from the regex
}
Regex removeCache(Regex regex) = 
    visit(regex) {
        case cached(exp, _, _) => exp
    };
&T removeRegexCache(&T anything) = 
    visit(anything) {
        case Regex::cached(exp, _, _) => exp
    };

@doc {
    Removes the cache from sub-regexes, but keeps the outer cache
}
&T removeInnerRegexCache(&T anything) 
    = top-down-break visit(anything) {
        case Regex::cached(exp, dfa, scoped) => cached(removeRegexCache(exp), dfa, scoped)
    };


@doc {
    Checks whether the given regular expression contains a scope
}
bool containsScopes(Regex regex) {
    if(cached(_, _, hasScope) := regex) return hasScope;

    hasScope = /scopeTag(_) := regex;
    return hasScope;
}

@doc {
    Retrieves the PSNFA of the given regular expression, and the regular expression with the PSNFA cached into it for quick access later (using this same function)
}
tuple[Regex, NFA[State]] cachedRegexToPSNFA(Regex regex) = cachedRegexToPSNFAandContainsScopes(regex)<0, 1>;

@doc {
    Retrieves only the input regex, but already caches the PSNFA and contains scopes data into there for later use
}
Regex getCachedRegex(Regex regex) = cachedRegexToPSNFAandContainsScopes(regex)<0>;

@doc {
    Checks whether the given regular expression contains a scope, and retrieves a regular expression with this data cached into it. 
}
tuple[Regex, NFA[State]] cachedContainsScopes(Regex regex) = cachedRegexToPSNFAandContainsScopes(regex)<0, 2>;

@doc {
    Retrieves the PSNFA of the given regular expression, whether the expression contains any scopes, and a regular expression with this data cached into it. 
}
tuple[Regex, NFA[State], bool] cachedRegexToPSNFAandContainsScopes(Regex regex) {
    if (cached(regex, n, hasScope) := regex) return <regex, n, hasScope>;

    n = regexToPSNFA(regex);
    hasScope = containsScopes(regex);
    return <cached(regex, n, hasScope), n, hasScope>;
}
