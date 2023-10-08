module regex::RegexProperties

import ParseTree;

import regex::util::charClass;
import regex::RegexTypes;

@doc {
    Checks whether the given regular expression contains a scope
}
bool containsScopes(Regex regex) {
    if(meta(_, cacheMeta(_, <hasScope, _>)) := regex) return hasScope;

    hasScope = /scopeTag(_) := regex;
    return hasScope;
}

@doc {
    Checks whether this regular expression contains a newline character
}
bool containsNewline(Regex regex) {
    if(meta(_, cacheMeta(_, <_, hasNewline>)) := regex) return hasNewline;

    newline = [range(10, 10)];
    hasNewline = /character(cc) := regex && size(fIntersection(cc, newline))>0;
    return hasNewline;
}