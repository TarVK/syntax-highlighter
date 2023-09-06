module conversion::util::makeLookahead

import regex::Regex;
import conversion::util::RegexCache;

@doc {
    Turns the given regex into a lookahead regex. 
    Keeps the regex unchanged if it already was a lookahead
}
Regex makeLookahead(Regex regex) {
    if(lookahead(empty(), _) := regex) return regex;
    if(cached(lookahead(empty(), _), _, _) := regex) return regex;

    la = lookahead(empty(), regex);
    return getCachedRegex(la);
}