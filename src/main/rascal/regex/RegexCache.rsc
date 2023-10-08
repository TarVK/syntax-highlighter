module regex::RegexCache

import regex::RegexTypes;
import regex::PSNFATypes;
import regex::RegexProperties;
import regex::regexToPSNFA;

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
    if (meta(_, cacheMeta(n, <hasScope, hasNewline>)) := regex) return <regex, n, <hasScope, hasNewline>>;

    n = regexToPSNFA(regex, simplify);
    hasScope = containsScopes(regex);
    hasNewline = containsNewline(regex);
    return <meta(regex, cacheMeta(n, <hasScope, hasNewline>)), n, <hasScope, hasNewline>>;
}
