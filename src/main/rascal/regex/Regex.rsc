module regex::Regex

import lang::rascal::grammar::definition::Characters;
import lang::rascal::format::Escape;
import ParseTree;
import String;
import IO;

import regex::util::GetDisjointCharClasses;
import regex::util::AnyCharClass;
import regex::RegexSyntax;
import Scope;

data Regex = never()
           | empty()
           | always()
           | character(list[CharRange] ranges)
           | lookahead(Regex r, Regex lookahead)
           | lookbehind(Regex r, Regex lookbehind)
           | \negative-lookahead(Regex r, Regex lookahead)
           | \negative-lookbehind(Regex r, Regex lookbehind)
           | concatenation(Regex head, Regex tail)
           | alternation(Regex opt1, Regex opt2)
           | \multi-iteration(Regex r)
           | subtract(Regex r, Regex removal)
           | scoped(Scope::Scopes scopes, Regex r)
           // Additional extended syntax, translatable into the core
           | concatenation(list[Regex] parts)
           | alternation(list[Regex] options)
           | iteration(Regex r)
           | optional(Regex r)
           | \exact-iteration(Regex r, int amount)
           | \min-iteration(Regex r, int min)
           | \max-iteration(Regex r, int max)
           | \min-max-iteration(Regex r, int min, int max);

//     Reduction
// ---------------------
@doc {
    Gets rid of the extended syntax in the regex
}
Regex reduce(Regex inp) {
    return visit (inp) {
        case Regex::concatenation([]) => empty()
        case Regex::concatenation([part]) => part
        case Regex::concatenation([first, second, *rest]) => 
            (concatenation(first, second) | concatenation(it, part) | part <- rest)

        case Regex::alternation([]) => empty()
        case Regex::alternation([opt]) => opt
        case Regex::alternation([opt1, opt2, *rest]) => 
            (concatenation(opt1, opt2) | concatenation(it, part) | part <- rest)

        case Regex::iteration(r) =>
            alternation(\multi-iteration(r), empty())

        case Regex::optional(r) => alternation(r, empty())

        case Regex::\exact-iteration(r, amount) => repeat(r, amount)

        case Regex::\min-iteration(r, 0) => alternation(\multi-iteration(r), empty())
        case Regex::\min-iteration(r, 1) => \multi-iteration(r)
        case Regex::\min-iteration(r, min) => (\multi-iteration(r) | concatenation(r, it) | _ <- [1..min])

        case Regex::\max-iteration(r, max) => expandMaxIteration(r, max)

        case Regex::\min-max-iteration(r, min, max) => repeat(r, min) when min == max
        case Regex::\min-max-iteration(_, min, max) => never() when min > max
        case Regex::\min-max-iteration(r, min, max) => 
            concatenation(repeat(r, min), expandMaxIteration(r, max-min))

    }
}
Regex repeat(Regex r, 0) = empty();
Regex repeat(Regex r, 1) = r;
Regex repeat(Regex r, int min) = (r | concatenation(r, it) | _ <- [1..min]);

Regex expandMaxIteration(Regex r, 0) = empty();
Regex expandMaxIteration(Regex r, int max) = (alternation(r, empty()) | alternation(concatenation(r, it), empty()) | _ <- [1..max]);


//       Parsing
// ------------------
Regex parseRegexReduced(str text) = reduce(parseRegex(text));
Regex parseRegex(str text) = CSTtoRegex(parse(#RegexCST, text));

Regex CSTtoRegex(RegexCST regex) {
    switch(regex) {
        case (RegexCST)`$0`: return never();
        case (RegexCST)`$e`: return empty();
        case (RegexCST)`$1`: return always();

        case (RegexCST)`<RawChar char>`: {
            code = charAt("<char>", 0);
            return Regex::character([range(code, code)]);
        }
        case (RegexCST)`<ChararacterClass chars>`: return character(CSTtoChararacterClass(chars));
        case (RegexCST)`<RegexCST cst>+`: return \multi-iteration(CSTtoRegex(cst));
        case (RegexCST)`<RegexCST cst>*`: return iteration(CSTtoRegex(cst));

        case (RegexCST)`<RegexCST cst>{<Num amount>}`: return \exact-iteration(CSTtoRegex(cst), CSTtoNumber(amount));
        case (RegexCST)`<RegexCST cst>{<Num min>,}`: return \min-iteration(CSTtoRegex(cst), CSTtoNumber(min));
        case (RegexCST)`<RegexCST cst>{,<Num max>}`: return \max-iteration(CSTtoRegex(cst), CSTtoNumber(max));
        case (RegexCST)`<RegexCST cst>{<Num min>,<Num max>}`: return \min-max-iteration(CSTtoRegex(cst), CSTtoNumber(min), CSTtoNumber(max));
        case (RegexCST)`<RegexCST cst>?`: return optional(CSTtoRegex(cst));
        
        case (RegexCST)`<RegexCST cst>\><RegexCST la>`: return lookahead(CSTtoRegex(cst),CSTtoRegex(la));
        case (RegexCST)`<RegexCST cst>!\><RegexCST nla>`: return \negative-lookahead(CSTtoRegex(cst),CSTtoRegex(nla));
        case (RegexCST)`<RegexCST lb>\<<RegexCST cst>`: return lookbehind(CSTtoRegex(cst),CSTtoRegex(lb));
        case (RegexCST)`<RegexCST nlb>!\<<RegexCST cst>`: return \negative-lookbehind(CSTtoRegex(cst),CSTtoRegex(nlb));
        case (RegexCST)`\><RegexCST la>`: return lookahead(empty(),CSTtoRegex(la));
        case (RegexCST)`!\><RegexCST nla>`: return \negative-lookahead(empty(),CSTtoRegex(nla));
        case (RegexCST)`<RegexCST lb>\<`: return lookbehind(empty(), CSTtoRegex(lb));

        case (RegexCST)`<RegexCST exp>\\<RegexCST subt>`: return subtract(CSTtoRegex(exp), CSTtoRegex(subt));
        case (RegexCST)`\\<RegexCST subt>`: return subtract(always(), CSTtoRegex(subt));

        case (RegexCST)`<RegexCST head><RegexCST tail>`: return concatenation(CSTtoRegex(head),CSTtoRegex(tail));
        case (RegexCST)`<RegexCST opt1>|<RegexCST opt2>`: return alternation(CSTtoRegex(opt1),CSTtoRegex(opt2));
        case (RegexCST)`(<RegexCST cst>)`: return CSTtoRegex(cst);
        case (RegexCST)`(\<<ScopesCST scopes>\><RegexCST cst>)`: return scoped(CSTtoScopes(scopes), CSTtoRegex(cst));
    }
    return empty();
}

list[CharRange] CSTtoChararacterClass(ChararacterClass chars) { 
    switch(chars) {
        case (ChararacterClass)`.`: return anyCharClass();
        case (ChararacterClass)`[<RangeCST* ranges>]`: return [CSTtoCharRange(range) | range <- ranges];
        case (ChararacterClass)`!<ChararacterClass charClass>`: return fComplement(CSTtoChararacterClass(charClass));
        case (ChararacterClass)`<ChararacterClass lhs>-<ChararacterClass rhs>`: return fDifference(CSTtoChararacterClass(lhs), CSTtoChararacterClass(rhs));
        case (ChararacterClass)`<ChararacterClass lhs>||<ChararacterClass rhs>`: return fUnion(CSTtoChararacterClass(lhs), CSTtoChararacterClass(rhs));
        case (ChararacterClass)`<ChararacterClass lhs>&&<ChararacterClass rhs>`: return fIntersection(CSTtoChararacterClass(lhs), CSTtoChararacterClass(rhs));
        case (ChararacterClass)`{<ChararacterClass charClass>}`: return CSTtoChararacterClass(charClass);
    }
    return [];
}
CharRange CSTtoCharRange(RangeCST range) {
    switch(range) {
        case (RangeCST)`<Char begin>-<Char end>`: return CharRange::range(CSTtoCharCode(begin), CSTtoCharCode(end));
        case (RangeCST)`<Char char>`: return CharRange::range(CSTtoCharCode(char), CSTtoCharCode(char));
    }
    return CharRange::range(0, 0);
}
int CSTtoCharCode(Char char) = size("<char>")==1 ? charAt("<char>", 0) : charAt("<char>", 1);
int CSTtoNumber(Num number) = toInt("<number>");

Scope::Scopes CSTtoScopes(ScopesCST scopes) {
    if((ScopesCST)`<{ScopeCST ","}+ scopesT>` := scopes) {
        Scope::Scopes out = [];
        for((ScopeCST)`<{TokenCST "."}+ scopeT>` <- scopesT) {
            Scope::Scope scope = [];
            for((TokenCST)`<RawChar+ chars>` <- scopeT) {
                scope += "<chars>";
            }
            out += [scope];
        }
        return out;
    }
    return [];
}

//    stringifying
// -------------------
str stringify(Regex regex) {
    // TODO: improve to consider associativity instead of just adding brackets everywhere
    switch(regex) {
        case Regex::never(): return "$0";
        case Regex::empty(): return "$e";
        case Regex::always(): return "$1";
        case Regex::character(cc): return stringify(cc);
        case Regex::lookahead(r, la): return "(<stringify(r)>)\>(<stringify(la)>)";
        case Regex::lookbehind(r, lb): return "(<stringify(lb)>)\<(<stringify(r)>)";
        case Regex::\negative-lookahead(r, la): return "(<stringify(r)>)!\>(<stringify(la)>)";
        case Regex::\negative-lookbehind(r, lb): return "(<stringify(lb)>)!\<(<stringify(r)>)";
        case Regex::concatenation(h, t): return "(<stringify(h)>)(<stringify(t)>)";
        case Regex::alternation(h, t): return "(<stringify(h)>)|(<stringify(t)>)";
        case Regex::\multi-iteration(r): return "(<stringify(r)>)+";
        case Regex::subtract(r, s): return "(<stringify(r)>)-(<stringify(s)>)";
        case Regex::concatenation([]): return "$e";
        case Regex::concatenation([first]): return stringify(first);
        case Regex::concatenation([first, *parts]): return ("(<stringify(first)>)" | it + "(<stringify(p)>)" | p <- parts);
        case Regex::alternation([]): return "$e";
        case Regex::alternation([first]): return stringify(first);
        case Regex::alternation([first, *parts]): return ("(<stringify(first)>)" | it + "|(<stringify(p)>)" | p <- parts);
        case Regex::iteration(r): return "(<stringify(r)>)*";
        case Regex::optional(r): return "(<stringify(r)>)?";
        case Regex::\exact-iteration(r, t): return "(<stringify(r)>){<t>}";
        case Regex::\min-iteration(r, min): return "(<stringify(r)>){<min>,}";
        case Regex::\max-iteration(r, max): return "(<stringify(r)>){,<max>}";
        case Regex::\min-max-iteration(r, min, max): return "(<stringify(r)>){<min>,<max>}";
        case Regex::scoped(n, r): return "(\<<stringify(n)>\><stringify(r)>)";
    }
    return "";
}
str stringify(CharClass cc) {
    hasMin = any(range(s, e) <- cc, s <= 1 && 1 <= e);
    hasMax = any(range(s, e) <- cc, s <= 0x10FFFF && 0x10FFFF <= e);
    negate = hasMin && hasMax;
    if (negate) cc = fComplement(cc);

    str chars = "";
    for(range(f, t)<-cc) {
        from = makeCharClassChar(f);
        to = makeCharClassChar(t);
        if(from == to) chars += from;
        else chars += from+"-"+to;
    }
    return negate ? (size(cc)==0 ? "." : "![<chars>]") : "[<chars>]";
}
str stringify(Scopes scopes) = stringify([stringify(scope, ".") | scope <- scopes], ",");
str stringify(list[str] scopes, str sep) = ("" | it + val | val <- intersperse(sep, scopes));
