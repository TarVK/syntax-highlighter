module mapping::monarch::splitMarkedUnions

import IO;

import regex::RegexTypes;

@doc {
    Splits the marked unions in a regular expression, such that:
    - The union of the output defines the same language as the input
    - No unions in the output regular expression contain mark expressions

    Assumes no markings to be present in iterations or lookarounds
}
list[Regex] splitMarkedUnions(Regex regex) {
    if(/mark(_, _) !:= regex) return [regex];

    rec = splitMarkedUnions;

    switch(regex) {
        case mark(tags, r): return [mark(tags, u) | u <- rec(r)];
        case lookahead(r, la): return [lookahead(u, la) | u <- rec(r)];
        case \negative-lookahead(r, la): return [\negative-lookahead(u, la) | u <- rec(r)];
        case lookbehind(r, lb): return [lookbehind(u, lb) | u <- rec(r)];
        case \negative-lookbehind(r, lb): return [\negative-lookbehind(u, lb) | u <- rec(r)];
        case subtract(r, sub): return [subtract(u, sub) | u <- rec(r)];
        case meta(r, m): return [meta(u, m) | u <- rec(r)];
        case concatenation(h, t): return [concatenation(ho, to) | ho <- rec(h), to <- rec(t)];
        case concatenation(seq): return [concatenation(combination) | combination <- combinations([rec(part) | part <- seq])];
        case alternation(o1, o2): return [*rec(o1), *rec(o2)];
        case alternation(options): return [*rec(opt) | opt <- options];
        case optional(r): return [empty(), *rec(r)];

        default: {
            println("Missed case in splitMarkedUnions: <regex>");
        }
    }

    return [];
}

list[list[&T]] combinations(list[list[&T]] sequence) {
    if([first, second] := sequence) 
        return [[ho, to] | ho <- first, to <- second];
    if([first, *rest] := sequence) 
        return [[ho, *to] | ho <- first, to <- combinations(rest)];
    return [];
}