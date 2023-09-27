module regex::RegexCache

import regex::RegexTypes;
import regex::PSNFATypes;
import regex::RegexProperties;
import regex::regexToPSNFA;

@doc {
    Removes all caches from the regex
}
&T removeRegexCache(&T anything) = 
    visit(anything) {
        case meta(exp, cacheMeta(_, _)) => exp
    };

@doc {
    Removes the cache from sub-regexes, but keeps the outer cache
}
&T removeInnerRegexCache(&T anything) 
    = top-down-break visit(anything) {
        case meta(exp, mc:cacheMeta(_, _)) => meta(removeRegexCache(exp), mc)
    };

@doc {
    Retrieves only the input regex, but already caches the PSNFA and contains scopes data into there for later use
}
Regex getCachedRegex(Regex regex) = cachedRegexToPSNFAandFlags(regex)<0>;
Regex getCachedRegex(Regex regex, bool shouldSimplify) = cachedRegexToPSNFAandFlags(regex, shouldSimplify)<0>;

@doc {
    Retrieves the PSNFA of the given regular expression, whether the expression contains any scopes, any newlines, and a regular expression with this data cached into it. 
}
tuple[Regex, NFA[State], tuple[bool, bool]] cachedRegexToPSNFAandFlags(Regex regex)
    = cachedRegexToPSNFAandFlags(regex, true);
tuple[Regex, NFA[State], tuple[bool, bool]] cachedRegexToPSNFAandFlags(Regex regex, bool simplify) {
    if (meta(regex, cacheMeta(n, <hasScope, hasNewline>)) := regex) return <regex, n, <hasScope, hasNewline>>;

    n = regexToPSNFA(regex, simplify);
    hasScope = containsScopes(regex);
    hasNewline = containsNewline(regex);
    return <meta(regex, cacheMeta(n, <hasScope, hasNewline>)), n, <hasScope, hasNewline>>;
}
