module conversion::util::makeLookahead

import regex::Regex;
import regex::RegexCache;

@doc {
    Turns the given regex into a lookahead regex. 
    Keeps the regex unchanged if it already was a lookahead
}
Regex makeLookahead(Regex regex)
    = makeLookahead(regex, true);
Regex makeLookahead(Regex regex, bool cachePSNFA) {
    r = regex;
    while(meta(r2, _) := r) r = r2;
    if(lookahead(empty(), _) := r) return regex;

    la = lookahead(empty(), regex);
    if(cachePSNFA) return getCachedRegex(la);
    return la;
}