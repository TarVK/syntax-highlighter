module mapping::ace::addRegexEndMatch

import ParseTree;

import regex::RegexTypes;
import regex::util::charClass;

@doc {
    Replaces every character group `X` that accepts \n or \r by `(X|eol)`. Eol can then be stringified such that it matches an End Of Line, even if the `\n` character is absent on this line. 
}
Regex addRegexEndMatch(Regex regex) = visit(regex) {
    case character(cc) => alternation(eol(), character(cc))
        when /character(cc) := regex && size(fIntersection(cc, newline))>0
};
CharClass newline = [range(10, 10)];