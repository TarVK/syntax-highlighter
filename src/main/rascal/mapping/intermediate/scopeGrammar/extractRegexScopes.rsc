module mapping::intermediate::scopeGrammar::extractRegexScopes

import List;
import IO;
import Set;

import regex::PSNFATools;
import regex::RegexCache;
import regex::Regex;
import Scope;

data CaptureGroup = captureGroup(int id);


@doc {
    Extracts all scopes of a regular expression and replaces them by IDed capture groups
}
tuple[Regex, list[Scope]] extractRegexScopes(Regex regex)
    = extractRegexScopes(regex, []);
tuple[Regex, list[Scope]] extractRegexScopes(Regex regex, list[Scope] scopes) {
    switch(regex) {
        case mark(tags, r): {
            /*
                If a scope `b` is contained under a parent scope `a`, it will be tagged with something like: 
                {scopeTag([a, b])}
            */
            if(
                {scopeTag(s:someScopes(_, _)), *rest} := tags, 
                scopeList := toList(s), 
                // Make sure we get an outermost scope, since both parent and child scope may be present on the same mark due to the scope lifting procedure
                !any(
                    scopeTag(s2:someScopes(_, _)) <- rest, 
                    scopeList2 := toList(s2),
                    [*scopeList2, _, *_] := scopeList
                )
            ) {
                scope = last(scopeList);

                if(size(rest) > 0) r = mark(rest, r); // Make sure the remaining scopes are also processed

                newCaptureGroup = captureGroup(size(scopes));
                scopes += [scope];
                <r, scopes> = extractRegexScopes(r, scopes);
                regex = mark({newCaptureGroup}, r);
            } else {
                regex = r;
            }
        }
        case meta(r, _): return extractRegexScopes(r, scopes);

        case never(): ;
        case empty(): ;
        case always(): ;
        case character(_): ;
        case lookahead(r, la): {
            <r, scopes> = extractRegexScopes(r, scopes);
            regex = lookahead(r, removeMarks(la));
        }
        case lookbehind(r, lb): {
            <r, scopes> = extractRegexScopes(r, scopes);
            regex = lookbehind(r, removeMarks(lb));
        }
        case \negative-lookahead(r, la): {
            <r, scopes> = extractRegexScopes(r, scopes);
            regex = \negative-lookahead(r, removeMarks(la));
        }
        case \negative-lookbehind(r, lb): {
            <r, scopes> = extractRegexScopes(r, scopes);
            regex = \negative-lookbehind(r, removeMarks(lb));
        }
        case concatenation(h, t): {
            <h, scopes> = extractRegexScopes(h, scopes);
            <t, scopes> = extractRegexScopes(t, scopes);
            regex = concatenation(h, t);
        }
        case alternation(o1, o2): {
            <o1, scopes> = extractRegexScopes(o1, scopes);
            <o2, scopes> = extractRegexScopes(o2, scopes);
            regex = concatenation(o1, o2);
        }
        case \multi-iteration(r): regex = \multi-iteration(removeMarks(r));
        case subtract(r, s): {
            <r, scopes> = extractRegexScopes(r, scopes);
            regex = subtract(r, removeMarks(s));
        }
        case eol(): ;
        case sol(): ;
        case concatenation(parts): {
            list[Regex] out = [];
            for(part <- parts) {
                <part, scopes> = extractRegexScopes(part, scopes);
                out += part;
            }
            regex = concatenation(out);
        }
        case alternation(options): {
            list[Regex] out = [];
            for(option <- options) {
                <option, scopes> = extractRegexScopes(option, scopes);
                out += option;
            }
            regex = alternation(out);
        }
        case iteration(r): regex = iteration(removeMarks(r));
        case optional(r): {
            <r, scopes> = extractRegexScopes(r, scopes);
            regex = optional(r);
        }
        case \exact-iteration(r, amount): regex = \exact-iteration(removeMarks(r), amount);
        case \min-iteration(r, min): regex = \min-iteration(removeMarks(r), min);
        case \max-iteration(r, max): regex = \max-iteration(removeMarks(r), max);
        case \min-max-iteration(r, min, max): regex = \min-max-iteration(removeMarks(r), min, max);
        default: {
            // Unsupported, shouldn't happen
            println("Missed a case in extractRegexScopes implementation: <regex>");
        }
    }

    return <regex, scopes>;
}

Regex removeMarks(Regex regex) = visit(regex) {
    case mark(_, r) => r
};
