module regex::Regex
extend regex::RegexTypes;

import lang::rascal::grammar::definition::Characters;
import lang::rascal::format::Escape;
import ParseTree;
import String;
import IO;

import regex::util::GetDisjointCharClasses;
import regex::util::charClass;
import regex::RegexSyntax;
import regex::Tags;
import util::List;
import regex::RegexTypes;
import regex::RegexStripping;
import Scope;

//     Reduction
// ---------------------
@doc {
    Gets rid of the extended syntax in the regex
}
Regex reduce(Regex inp) {
    return visit (inp) {
        case r:Regex::concatenation(_) => reduceConcatenation(r)
        case r:Regex::alternation(_) => reduceAlternation(r)

        case Regex::iteration(r) =>
            alternation(\multi-iteration(r), empty())

        case Regex::optional(r) => alternation(r, empty())

        case Regex::eol() => eolRegex()
        case Regex::sol() => solRegex()

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

Regex reduceAlternation(Regex::alternation([])) = never();
Regex reduceAlternation(Regex::alternation([option])) = option;
Regex reduceAlternation(Regex::alternation([opt1, opt2, *rest])) 
    = (simplifiedAlternation(opt1, opt2) | simplifiedAlternation(it, part) | part <- rest);

Regex reduceConcatenation(Regex::concatenation([])) = empty();
Regex reduceConcatenation(Regex::concatenation([part])) = part;
Regex reduceConcatenation(Regex::concatenation([first, second, *rest])) 
    = (simplifiedConcatenation(first, second) | simplifiedConcatenation(it, part) | part <- rest);

Regex simplifiedAlternation(Regex n, Regex b) = b
    when removeOuterMeta(n) == never();
Regex simplifiedAlternation(Regex a, Regex n) = a
    when removeOuterMeta(n) == never();
// Regex simplifiedAlternation(Regex e, Regex b) = e // Only holds if there are no tagged lookaheads
//     when removeOuterMeta(e) == empty();
// Regex simplifiedAlternation(Regex a, Regex e) = e
//     when removeOuterMeta(e) == empty();
Regex simplifiedAlternation(Regex a, Regex b) = a
    when removeOuterMeta(a) == removeOuterMeta(b);
Regex simplifiedAlternation(Regex a, Regex b) = alternation(a, b);

Regex simplifiedConcatenation(Regex a, Regex b) = never()
    when removeOuterMeta(a) == never() || removeOuterMeta(b) == never();
Regex simplifiedConcatenation(Regex e, Regex b) = b
    when removeOuterMeta(e) == empty();
Regex simplifiedConcatenation(Regex a, Regex e) = a
    when removeOuterMeta(e) == empty();
Regex simplifiedConcatenation(Regex a, Regex b) = concatenation(a, b);

Regex simplifiedLookahead(Regex r, Regex la) = never()
    when removeOuterMeta(r) == never();
Regex simplifiedLookahead(Regex r, Regex la) = r
    when removeOuterMeta(la) == empty();
Regex simplifiedLookahead(Regex r, Regex la) = never()
    when removeOuterMeta(la) == never();
Regex simplifiedLookahead(Regex r, Regex la) = lookahead(r, la);
    
Regex simplifiedNegativeLookahead(Regex r, Regex la) = never()
    when removeOuterMeta(r) == never();
Regex simplifiedNegativeLookahead(Regex r, Regex la) = r
    when removeOuterMeta(la) == never();
Regex simplifiedNegativeLookahead(Regex r, Regex la) = never()
    when removeOuterMeta(la) == empty();
Regex simplifiedNegativeLookahead(Regex r, Regex la) = \negative-lookahead(r, la);

Regex simplifiedLookbehind(Regex r, Regex la) = never()
    when removeOuterMeta(r) == never();
Regex simplifiedLookbehind(Regex r, Regex la) = r
    when removeOuterMeta(la) == empty();
Regex simplifiedLookbehind(Regex r, Regex la) = never()
    when removeOuterMeta(la) == never();
Regex simplifiedLookbehind(Regex r, Regex la) = lookbehind(r, la);
    
Regex simplifiedNegativeLookbehind(Regex r, Regex la) = never()
    when removeOuterMeta(r) == never();
Regex simplifiedNegativeLookbehind(Regex r, Regex la) = r
    when removeOuterMeta(la) == never();
Regex simplifiedNegativeLookbehind(Regex r, Regex la) = never()
    when removeOuterMeta(la) == empty();
Regex simplifiedNegativeLookbehind(Regex r, Regex la) = \negative-lookbehind(r, la);

@doc {
    A regular expression representing the end of a line
}
Regex eolRegex() = alternation(
    \negative-lookahead(empty(), Regex::character(anyCharClass())), // EOF (no more characters)
    lookahead(empty(), newLine())
);

@doc {
    A regular expression representing the  start of a line
}
Regex solRegex() = alternation(
    \negative-lookbehind(empty(), Regex::character(anyCharClass())), // SOF (no more characters)
    lookbehind(empty(), newLine())
);

Regex newLine() = alternation(
    \negative-lookbehind(Regex::character([range(10, 10)]), Regex::character([range(13, 13)])),  // \n (without \r in front)
    concatenation(Regex::character([range(13, 13)]), Regex::character([range(10, 10)])) // \r\n
);

//       Parsing
// ------------------
Regex parseRegexReduced(str text) = reduce(parseRegex(text));
Regex parseRegex(str text) = CSTtoRegex(parse(#RegexCST, text));

Regex CSTtoRegex(RegexCST regex) = CSTtoRegex(regex, []);
Regex CSTtoRegex(RegexCST regex, ScopeList scopes) {
    Regex r(RegexCST regex) = CSTtoRegex(regex, scopes);
    switch(regex) {
        case (RegexCST)`$0`: return never();
        case (RegexCST)`$e`: return empty();
        case (RegexCST)`$1`: return always();
        case (RegexCST)`$$`: return eol();
        case (RegexCST)`^`: return sol();

        case (RegexCST)`<RawChar char>`: {
            code = charAt("<char>", 0);
            return Regex::character([range(code, code)]);
        }
        case (RegexCST)`<ChararacterClass chars>`: return character(CSTtoChararacterClass(chars));
        case (RegexCST)`<RegexCST cst>+`: return \multi-iteration(r(cst));
        case (RegexCST)`<RegexCST cst>*`: return iteration(r(cst));

        case (RegexCST)`<RegexCST cst>{<Num amount>}`: return \exact-iteration(r(cst), CSTtoNumber(amount));
        case (RegexCST)`<RegexCST cst>{<Num min>,}`: return \min-iteration(r(cst), CSTtoNumber(min));
        case (RegexCST)`<RegexCST cst>{,<Num max>}`: return \max-iteration(r(cst), CSTtoNumber(max));
        case (RegexCST)`<RegexCST cst>{<Num min>,<Num max>}`: return \min-max-iteration(r(cst), CSTtoNumber(min), CSTtoNumber(max));
        case (RegexCST)`<RegexCST cst>?`: return optional(r(cst));
        
        case (RegexCST)`<RegexCST cst>\><RegexCST la>`: return lookahead(r(cst), r(la));
        case (RegexCST)`<RegexCST cst>!\><RegexCST nla>`: return \negative-lookahead(r(cst), r(nla));
        case (RegexCST)`<RegexCST lb>\<<RegexCST cst>`: return lookbehind(r(cst), r(lb));
        case (RegexCST)`<RegexCST nlb>!\<<RegexCST cst>`: return \negative-lookbehind(r(cst), r(nlb));
        case (RegexCST)`\><RegexCST la>`: return lookahead(empty(), r(la));
        case (RegexCST)`!\><RegexCST nla>`: return \negative-lookahead(empty(), r(nla));
        case (RegexCST)`<RegexCST lb>\<`: return lookbehind(empty(), r(lb));
        case (RegexCST)`<RegexCST nlb>!\<`: return \negative-lookbehind(empty(), r(nlb));

        case (RegexCST)`<RegexCST exp>\\<RegexCST subt>`: return subtract(r(exp), r(subt));
        case (RegexCST)`\\<RegexCST subt>`: return subtract(always(), r(subt));

        case (RegexCST)`<RegexCST head><RegexCST tail>`: return concatenation(r(head), r(tail));
        case (RegexCST)`<RegexCST opt1>|<RegexCST opt2>`: return alternation(r(opt1), r(opt2));
        case (RegexCST)`(<RegexCST cst>)`: return r(cst);
        case (RegexCST)`(\<<ScopesCST scopesCST>\><RegexCST cst>)`: {
            newSCopes = scopes + CSTtoScopes(scopesCST);
            return mark({scopeTag(toScopes(newSCopes))}, CSTtoRegex(cst, newSCopes));
        }
    }

    println("Error: missed a case: <regex>");
    return empty();
}

list[CharRange] CSTtoChararacterClass(ChararacterClass chars) { 
    switch(chars) {
        case (ChararacterClass)`.`: return anyCharClass();
        case (ChararacterClass)`[<RangeCST* ranges>]`: 
            return ([] | fUnion(it, [CSTtoCharRange(r)]) | r <- ranges);
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

Scope::ScopeList CSTtoScopes(ScopesCST scopes) {
    if((ScopesCST)`<{ScopeCST ","}+ scopesT>` := scopes) {
        Scope::ScopeList out = [];
        for((ScopeCST)`<{TokenCST "."}+ scopeT>` <- scopesT) {
            Scope::Scope scope = "";
            for((TokenCST)`<RawChar+ chars>` <- scopeT) {
                scope += ".<chars>";
            }
            out += [scope[1..]];
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
        case Regex::eol(): return "$$";
        case Regex::sol(): return "^";
        case Regex::character(cc): return stringify(cc);
        case Regex::lookahead(r, la): return "(<stringify(r)>)\>(<stringify(la)>)";
        case Regex::lookbehind(r, lb): return "(<stringify(lb)>)\<(<stringify(r)>)";
        case Regex::\negative-lookahead(r, la): return "(<stringify(r)>)!\>(<stringify(la)>)";
        case Regex::\negative-lookbehind(r, lb): return "(<stringify(lb)>)!\<(<stringify(r)>)";
        case Regex::concatenation(h, t): return "(<stringify(h)>)(<stringify(t)>)";
        case Regex::alternation(h, t): return "(<stringify(h)>)|(<stringify(t)>)";
        case Regex::\multi-iteration(r): return "(<stringify(r)>)+";
        case Regex::subtract(r, s): return "(<stringify(r)>)\\(<stringify(s)>)";
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
        case Regex::mark(n, r): return "(\<<stringify(n)>\><stringify(r)>)";
    }
    return "";
}

str stringify(Tags t) = stringify([stringify(scopes) | scopeTag(scopes) <- t], ",");
