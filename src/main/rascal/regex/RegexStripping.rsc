module regex::RegexStripping

import regex::RegexTypes;
import regex::RegexCache;
import regex::RegexProperties;
import regex::PSNFACombinators;
import regex::PSNFASimplification;

@doc {
    Removes all meta data from a regular expression
}
&T removeMeta(&T anything) 
    = visit(anything) {
        case meta(r, m) => r
    };

@doc {
    Removes the outer layer of meta data, until a non-meta expression is reached
}
Regex removeOuterMeta(meta(regex, _)) = removeOuterMeta(regex);
Regex removeOuterMeta(Regex regex) = regex;

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
    Removes all tags from the given regular expression
}
Regex removeTags(Regex regex)
    = removeTags(regex, true);
Regex removeTags(Regex regex, bool cached)  {
    if(!containsScopes(regex)) return regex;

    // Remove all marks from regex
    regex = visit(regex) {
        case mark(_, r) => r
    };

    // Remove all tags from cached nfas
    regex = removeInnerRegexCache(regex);
    regex = visit(regex) {
        case meta(r, cacheMeta(nfa, <hasScope, hasNewline>)): {
            // Remove tags from nfas
            nfa = replaceTagsClasses(nfa, {{}});
            nfa = minimizeUnique(nfa);
            insert meta(r, cacheMeta(nfa, <false, hasNewline>));
        }
    }

    if(cached) regex = getCachedRegex(regex);
    return regex;
}