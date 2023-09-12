module conversion::util::RegexCache

extend regex::RegexToPSNFA;

import IO;
import lang::rascal::grammar::definition::Characters;
import ParseTree;

import regex::RegexTypes;
import regex::Regex;
import regex::RegexToPSNFA;
import regex::NFA;
import regex::PSNFATypes;
import regex::PSNFACombinators;

// Create a new regex constructor an related functions
data Regex = cached(
    Regex exp, 
    NFA[State] psnfa, 
    tuple[
        bool hasScope,
        bool hasNewline
    ] flags
);
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
        case Regex::cached(exp, dfa, flags) => cached(removeRegexCache(exp), dfa, flags)
    };


@doc {
    Checks whether the given regular expression contains a scope
}
bool containsScopes(Regex regex) {
    if(cached(_, _, <hasScope, _>) := regex) return hasScope;

    hasScope = /scopeTag(_) := regex;
    return hasScope;
}

@doc {
    Checks whether this regular expression contains a newline character
}
bool containsNewline(Regex regex) {
    if(cached(_, _, <_, hasNewline>) := regex) return hasNewline;

    newline = [range(10, 10)];
    hasNewline = /character(cc) := regex && any(r <- intersection(cc, newline), r != \empty-range());
    return hasNewline;
}


@doc {
    Retrieves only the input regex, but already caches the PSNFA and contains scopes data into there for later use
}
Regex getCachedRegex(Regex regex) = cachedRegexToPSNFAandFlags(regex)<0>;

@doc {
    Retrieves the PSNFA of the given regular expression, whether the expression contains any scopes, any newlines, and a regular expression with this data cached into it. 
}
tuple[Regex, NFA[State], tuple[bool, bool]] cachedRegexToPSNFAandFlags(Regex regex) {
    if (cached(regex, n, <hasScope, hasNewline>) := regex) return <regex, n, <hasScope, hasNewline>>;

    n = regexToPSNFA(regex);
    hasScope = containsScopes(regex);
    hasNewline = containsNewline(regex);
    return <cached(regex, n, <hasScope, hasNewline>), n, <hasScope, hasNewline>>;
}
