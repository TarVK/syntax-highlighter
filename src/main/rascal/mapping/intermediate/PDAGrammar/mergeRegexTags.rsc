module mapping::intermediate::PDAGrammar::mergeRegexTags

import IO;

import regex::RegexTypes;
import regex::RegexProperties;
import regex::Tags;

alias TagMerge = Tags(list[Tags] tags);

@doc {
    Merges all the tags that apply to a given regex, such that the final result has no nested tags declarations
}
Regex mergeRegexTags(Regex regex, TagMerge merge) {
    if(/mark(_, _) !:= regex) {
        tags = merge([]);
        return tags == {} ? regex : mark(tags, regex);
    }

    Regex rec(Regex r) = mergeRegexTags(r, merge);
    switch(regex) {
        case mark(tags, r):
            return mergeRegexTags(
                r,
                Tags(list[Tags] newTags) { return merge([tags] + newTags);}
            );
        case lookahead(r, la): return lookahead(rec(r), la);
        case \negative-lookahead(r, la): return \negative-lookahead(rec(r), la);
        case lookbehind(r, lb): return lookbehind(rec(r), lb);
        case \negative-lookbehind(r, lb): return \negative-lookahead(rec(r), lb);
        case subtract(r, sub): return subtract(rec(r), sub);
        case meta(r, m): return meta(rec(r), m);
        case concatenation(h, t): return concatenation(rec(h), rec(t));
        case concatenation(seq): return concatenation([rec(r) | r <- seq]);
        case alternation(o1, o2): return alternation(rec(o1), rec(o2));
        case alternation(opts): return alternation([rec(opt) | opt <- opts]);
        case \multi-iteration(r): return \multi-iteration(rec(r));
        case iteration(r): return iteration(rec(r));
        case \exact-iteration(r, a): return \exact-iteration(rec(r), a);
        case \min-iteration(r, a): return \min-iteration(rec(r), a);
        case \max-iteration(r, a): return \max-iteration(rec(r), a);
        case \min-max-iteration(r, mi, ma): return \min-max-iteration(rec(r), mi, ma);
        case optional(r): return optional(rec(r));
        default: {
            println("Missed case in mergeRegexTags: <regex>");
        }
    }

    return regex;
}

Tags defualtMerge(list[Tags] tagsList) = {*tags | tags <- tagsList};