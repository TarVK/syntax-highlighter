module mapping::intermediate::scopeGrammar::cleanupRegex

import List;
import IO;

import regex::PSNFATools;
import regex::RegexCache;
import regex::Regex;
import Scope;

@doc {
    Applies some transformation rules to the regexes to make it more concise and hence easier to read,
    the output is equivalent to the input, but uses extended syntax
}
Regex cleanupRegex(Regex regex) {
    eolR = eolRegex();
    solR = solRegex();
    return visit(regex) {
        // EOL and SOL
        case eolR => eol()
        case solR => sol()

        // iteration
        case alternation(\multi-iteration(r), empty()) => iteration(r)
        case alternation(empty(), \multi-iteration(r)) => iteration(r)

        // Lookarounds
        case lookahead(_, never()) => never()
        case lookbehind(_, never()) => never()
        case lookahead(r, empty()) => r
        case lookbehind(r, empty()) => r
        case \negative-lookahead(r, never()) => r
        case \negative-lookbehind(r, never()) => r
        case \negative-lookahead(_, empty()) => never()
        case \negative-lookbehind(_, empty()) => never()

        // Optionality
        case alternation(r, empty()) => optional(r)
        case alternation(empty(), r) => optional(r)
        case alternation([empty(), *parts]) => optional(alternation([part | part <- parts, part!=empty()]))

        // Alternation merging
        case alternation([*s, d, *m, d, *e]) => alternation([*s, d, *m, *e]) // dedupe
        case alternation(alternation(options1), alternation(options2)) => alternation(options1 + options2)
        case alternation(alternation(options), option) => alternation(options + option)
        case alternation(option, alternation(options)) => alternation(option + options)
        case alternation(o1, o2) => alternation([o1, o2])

        // Concatenation merging
        case concatenation(concatenation(head), concatenation(tail)) => concatenation(head + tail)
        case concatenation(concatenation(head), tail) => concatenation(head + tail)
        case concatenation(head, concatenation(tail)) => concatenation(head + tail)
        case concatenation(head, tail) => concatenation([head, tail])
    };
}