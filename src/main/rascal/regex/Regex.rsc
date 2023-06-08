module regex::Regex

import lang::rascal::grammar::definition::Characters;
import ParseTree;
import String;

import regex::util::GetDisjointCharClasses;
import regex::RegexSyntax;

data Regex = never()
           | empty()
           | character(list[CharRange] ranges)
           | lookahead(Regex regex, Regex lookahead)
           | lookbehind(Regex regex, Regex lookbehind)
           | \negative-lookahead(Regex regex, Regex lookahead)
           | \negative-lookbehind(Regex regex, Regex lookbehind)
           | concatenation(Regex head, Regex tail)
           | alternation(Regex opt1, Regex opt2)
           | \multi-iteration(Regex regex)
           // Additional extended syntax, translatable into the core
           | concatenation(list[Regex] parts)
           | alternation(list[Regex] options)
           | iteration(Regex regex)
           | optional(Regex regex)
           | \exact-iteration(Regex regex, int amount)
           | \min-iteration(Regex regex, int min)
           | \max-iteration(Regex regex, int max)
           | \min-max-iteration(Regex regex, int min, int max);

Regex normalize(Regex inp) {
    return visit (inp) {
        case concatenation([]) => empty()
        case concatenation([part]) => part
        case concatenation([first, second, *rest]) => 
            (concatenation(first, second) | concatenation(it, part) | part <- rest)

        case alternation([]) => empty()
        case alternation([opt]) => opt
        case alternation([opt1, opt2, *rest]) => 
            (concatenation(opt1, opt2) | concatenation(it, part) | part <- rest)

        case Regex::iteration(regex) =>
            alternation(\multi-iteration(regex), empty())

        case Regex::optional(regex) => alternation(regex, empty())

        case \exact-iteration(regex, amount) => repeat(regex, amount)

        case \min-iteration(regex, 0) => alternation(\multi-iteration(regex), empty())
        case \min-iteration(regex, 1) => \multi-iteration(regex)
        case \min-iteration(regex, min) => (\multi-iteration(regex) | concatenation(regex, it) | _ <- [1..min])

        case \max-iteration(regex, max) => expandMaxIteration(regex, max)

        case \min-max-iteration(regex, min, max) => repeat(regex, min) when min == max
        case \min-max-iteration(_, min, max) => never() when min > max
        case \min-max-iteration(regex, min, max) => 
            concatenation(repeat(regex, min), expandMaxIteration(regex, max-min))

    }
}

Regex repeat(Regex regex, 0) = empty();
Regex repeat(Regex regex, 1) = regex;
Regex repeat(Regex regex, int min) = (regex | concatenation(regex, it) | _ <- [1..min]);

Regex expandMaxIteration(Regex regex, 0) = empty();
Regex expandMaxIteration(Regex regex, int max) = (alternation(regex, empty()) | alternation(concatenation(regex, it), empty()) | _ <- [1..max]);

Regex parseRegexNormalized(str text) = normalize(parseRegex(text));
Regex parseRegex(str text) = CSTtoRegex(parse(#RegexCST, text));

Regex CSTtoRegex(RegexCST regex) {
    switch(regex) {
        case (RegexCST)`<RawChar char>`: {
            code = charAt("<char>", 0);
            return character([range(code, code)]);
        }
        case (RegexCST)`<ChararacterClass chars>`: return character(CSTtoChararacterClass(chars));
        case (RegexCST)`<RegexCST cst>+`: return \multi-iteration(CSTtoRegex(cst));
        case (RegexCST)`<RegexCST cst>*`: return iteration(CSTtoRegex(cst));
        case (RegexCST)`<RegexCST cst>{<Num amount>}`: return \exact-iteration(CSTtoRegex(cst), CSTtoNumber(amount));
        case (RegexCST)`<RegexCST cst>{<Num min>,}`: return \min-iteration(CSTtoRegex(cst), CSTtoNumber(min));
        case (RegexCST)`<RegexCST cst>{,<Num max>}`: return \max-iteration(CSTtoRegex(cst), CSTtoNumber(max));
        case (RegexCST)`<RegexCST cst>{<Num min>,<Num max>}`: return \min-max-iteration(CSTtoRegex(cst), CSTtoNumber(min), CSTtoNumber(max));
        case (RegexCST)`<RegexCST cst>?`: return optional(CSTtoRegex(cst));
        case (RegexCST)`<RegexCST head><RegexCST tail>`: return concatenation(CSTtoRegex(head),CSTtoRegex(tail));
        
        case (RegexCST)`<RegexCST cst>\><RegexCST la>`: return lookahead(CSTtoRegex(cst),CSTtoRegex(la));
        case (RegexCST)`<RegexCST cst>!\><RegexCST nla>`: return \negative-lookahead(CSTtoRegex(cst),CSTtoRegex(nla));
        case (RegexCST)`<RegexCST lb>\<<RegexCST cst>`: return lookbehind(CSTtoRegex(cst),CSTtoRegex(lb));
        case (RegexCST)`<RegexCST nlb>!\<<RegexCST cst>`: return \negative-lookbehind(CSTtoRegex(cst),CSTtoRegex(nlb));
        case (RegexCST)`(\><RegexCST la>)`: return lookahead(empty(),CSTtoRegex(la));
        case (RegexCST)`(!\><RegexCST nla>)`: return \negative-lookahead(empty(),CSTtoRegex(nla));
        case (RegexCST)`(<RegexCST lb>\<)`: return lookbehind(empty(), CSTtoRegex(lb));
        case (RegexCST)`(<RegexCST nlb>!\<)`: return \negative-lookbehind(empty(), CSTtoRegex(nlb));

        case (RegexCST)`<RegexCST opt1>|<RegexCST opt2>`: return alternation(CSTtoRegex(opt1),CSTtoRegex(opt2));
        case (RegexCST)`(<RegexCST cst>)`: return CSTtoRegex(cst);
    }
    return empty();
}

list[CharRange] CSTtoChararacterClass(ChararacterClass chars) { 
    switch(chars) {
        case (ChararacterClass)`[<Range* ranges>]`: return [CSTtoCharRange(range) | range <- ranges];
        case (ChararacterClass)`!<ChararacterClass charClass>`: return fComplement(CSTtoChararacterClass(charClass));
        case (ChararacterClass)`<ChararacterClass lhs>-<ChararacterClass rhs>`: return fDifference(CSTtoChararacterClass(lhs), CSTtoChararacterClass(rhs));
        case (ChararacterClass)`<ChararacterClass lhs>||<ChararacterClass rhs>`: return fUnion(CSTtoChararacterClass(lhs), CSTtoChararacterClass(rhs));
        case (ChararacterClass)`<ChararacterClass lhs>&&<ChararacterClass rhs>`: return fIntersection(CSTtoChararacterClass(lhs), CSTtoChararacterClass(rhs));
        case (ChararacterClass)`{<ChararacterClass charClass>}`: return CSTtoChararacterClass(charClass);
    }
    return [];
}
CharRange CSTtoCharRange(Range range) {
    switch(range) {
        case (Range)`<Char begin>-<Char end>`: return CharRange::range(CSTtoCharCode(begin), CSTtoCharCode(end));
        case (Range)`<Char char>`: return CharRange::range(CSTtoCharCode(char), CSTtoCharCode(char));
    }
    return CharRange::range(0, 0);
}
int CSTtoCharCode(Char char) = size("<char>")==1 ? charAt("<char>", 0) : charAt("<char>", 1);
int CSTtoNumber(Num number) = toInt("<number>");