module mapping::common::stringifyOnigurumaRegex

import ParseTree;
import String;
import IO;

import regex::Regex;
import regex::util::GetDisjointCharClasses;
import mapping::common::addRegexBrackets;

@doc {
    Stringifies the given regular expression such that it's in Oniguruma format.
    Assumes that lookarounds have been split using `splitRegexLookarounds` such that lookarounds only have empty bodies, and subtractions have been removed
}
str stringifyOnigurumaRegex(Regex regex) {
    bracketed = addRegexBrackets(regex);
    return stringifyOnigurumaRegexRec(bracketed);
}
str stringifyOnigurumaRegexRec(Regex regex) {
    str rec(Regex regex) = stringifyOnigurumaRegexRec(regex);
    switch(regex) {
        // Lookarounds
        case lookahead(Regex::empty(), la): return "(?=<rec(la)>)";
        case group(lookahead(Regex::empty(), la)): return "(?=<rec(la)>)";

        case \negative-lookahead(Regex::empty(), la): return "(?!<rec(la)>)";
        case group(\negative-lookahead(Regex::empty(), la)): return "(?!<rec(la)>)";

        case lookbehind(Regex::empty(), lb): return "(?\<=<rec(lb)>)";
        case group(lookbehind(Regex::empty(), lb)): return "(?\<=<rec(lb)>)";

        case \negative-lookbehind(Regex::empty(), lb): return "(?\<!<rec(lb)>)";
        case group(\negative-lookbehind(Regex::empty(), lb)): return "(?\<!<rec(lb)>)";

        // Iterations
        case \multi-iteration(r): return "<rec(r)>+";
        case iteration(r): return "<rec(r)>*";
        case \exact-iteration(r, amount): return "<rec(r)>{<amount>,<amount>}";
        case \min-iteration(r, min): return "<rec(r)>{<min>,}";
        case \max-iteration(r, min): return "<rec(r)>{,<max>}";
        case \min-max-iteration(r, min): return "<rec(r)>{<min>,<max>}";
        case optional(r): return "<rec(r)>?";

        // Concatenation/alternation
        case concatenation(h, t): return "<rec(h)><rec(t)>";
        case concatenation([]): return emptyStr();
        case concatenation([h, *ts]): return (rec(h) | "<it><rec(t)>" | t <- ts);

        case alternation(o1, o2): return "<rec(o1)>|<rec(o2)>";
        case alternation([]): return neverStr();
        case alternation([first, *options]): return (rec(first) | "<it>|<rec(option)>" | option <- options);
        
        // Base cases
        case always(): return "(?:.*)";
        case Regex::empty(): return emptyStr();
        case never(): return neverStr();
        case eol(): return "$";
        case sol(): return "^";
        case character(cc): return stringifyOnigurumaCC(cc);

        // Groups
        case mark({captureGroup(_)}, r): return "(<rec(r)>)";
        case mark(_, r): return rec(r);
        case group(r): return "(?:<rec(r)>)";
    }

    println("Missed a case in stringifyOnigurumaRegex: <regex>");
    return "";
}

str neverStr() = "(?:x(?\<!x))";
str emptyStr() = "(?:)";

@doc{
    Converts the given character class to a Oniguruma character class
}
str stringifyOnigurumaCC(CharClass cc) {
    if([range(x, x)] := cc) return stringifyOnigurumaCharacter(x);

    hasMin = any(range(s, e) <- cc, s <= 1 && 1 <= e);
    hasMax = any(range(s, e) <- cc, s <= 0x10FFFF && 0x10FFFF <= e);
    negate = hasMin && hasMax;
    if (negate) cc = fComplement(cc);
    if([] := cc) return negate ? "." : emptStr();

    str chars = "";
    for(range(f, t)<-cc) {
        from = stringifyOnigurumaCharacter(f);
        to = stringifyOnigurumaCharacter(t);
        if(from == to) chars += from;
        else chars += from+"-"+to;
    }
    return negate ? (size(cc)==0 ? "." : "[^<chars>]") : "[<chars>]";
}

@doc {
    Retrieves a given character code in Oniguruma format
}
str stringifyOnigurumaCharacter(int char) {
    switch(char) {
        case 9: return "\\t";
        case 10: return "\\n";
        case 13: return "\\r";
        case 32: return " ";
        case 33: return "\\!";
        case 34: return "\\\"";
        case 35: return "\\#";
        case 36: return "\\$";
        case 37: return "\\%";
        case 38: return "\\&";
        case 39: return "\\\'";
        case 40: return "\\(";
        case 41: return "\\)";
        case 42: return "\\*";
        case 43: return "\\+";
        case 44: return "\\,";
        case 45: return "\\-";
        case 46: return "\\.";
        case 47: return "\\/";
        case 58: return "\\:";
        case 59: return "\\;";
        case 60: return "\\\<";
        case 61: return "\\=";
        case 62: return "\\\>";
        case 63: return "\\?";
        case 64: return "\\@";
        case 91: return "\\[";
        case 92: return "\\\\";
        case 93: return "\\]";
        case 94: return "\\^";
        case 95: return "\\_";
        case 96: return "\\`";
        case 123: return "\\{";
        case 124: return "\\|";
        case 125: return "\\}";
        case 126: return "\\~";
    }
    if(
        (48 <= char && char <= 57)
        || (65 <= char && char <= 90)
        || (97 <= char && char <= 122)
    )
        return stringChar(char);

    // Convert to hexadecimal
    str out = "";
    while(char>0) {
        remainder = char % 16;
        char = char / 16;
        out = stringChar(charAt("0123456789ABCDEF", remainder))+out;
    }

    return size(out)>2 ? "\\x<right(out, 2, "0")>" : "\\x{<right(out, 8, "0")>}";
}