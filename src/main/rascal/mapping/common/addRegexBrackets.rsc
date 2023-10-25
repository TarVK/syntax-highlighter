module mapping::common::addRegexBrackets

import regex::Regex;
import IO;

data Regex = group(Regex r);

@doc {
    Adds group constructs to the regular expressions, in such a way that precedence is respected.
    After this, stringifying without adding additional brackets will maintain the inteded hierarchy. 
}
Regex addRegexBrackets(Regex regex)
    = addRegexBracketsRec(regex)<0>;
tuple[Regex regex, int precedence] addRegexBracketsRec(Regex regex) {
    int precedence = 7; // Default to the highest precedence for the base cases

    Regex rec(Regex r)
        = rec(r, false);
    Regex rec(Regex r, bool wrapSamePrecedence) {
        <r, rPrecedence> = addRegexBracketsRec(r);
        if(rPrecedence < precedence)
            r = group(r);
        if(rPrecedence == precedence && wrapSamePrecedence)
            r = group(r);
        return r;
    }

    switch(regex) {
        // Level 1 precedence
        case lookbehind(r, lb): {
            precedence = 1;
            regex = lookbehind(rec(r, true), rec(lb));
        }
        case \negative-lookbehind(r, lb): {
            precedence = 1;
            regex = \negative-lookbehind(rec(r, true), rec(lb));
        }
        // Level 2 precedence
        case lookahead(r, la): {
            precedence = 2;
            regex = lookahead(rec(r, true), rec(la));
        }
        case \negative-lookahead(r, la): {
            precedence = 2;
            regex = \negative-lookahead(rec(r, true), rec(la));
        }
        // Level 3 precedence
        case subtract(r, s): {
            precedence = 3;
            regex = subtract(rec(r, true), rec(s));
        }
        // Level 4 precedence
        case alternation(o1, o2): {
            precedence = 4;
            regex = alternation(rec(o1), rec(o2));
        }
        case alternation(options): {
            precedence = 4;
            regex = alternation([rec(op) | op <- options]);
        }
        // Level 5 precedence
        case concatenation(head, tail): {
            precedence = 5;
            regex = concatenation(rec(head), rec(tail));
        }
        case concatenation(parts): {
            precedence = 5;
            regex = concatenation([rec(p) | p <- parts]);
        }
        // Level 6 precedence
        case \multi-iteration(r): {
            precedence = 6;
            regex = \multi-iteration(rec(r, true)); // Prevent accidental possessive operators by adding brackets to groups with the same precedence
        }
        case iteration(r): {
            precedence = 6;
            regex = iteration(rec(r));
        }
        case \exact-iteration(r, amount): {
            precedence = 6;
            regex = \exact-iteration(rec(r), amount);
        }
        case \min-iteration(r, min): {
            precedence = 6;
            regex = \min-iteration(rec(r), min);
        }
        case \max-iteration(r, max): {
            precedence = 6;
            regex = \max-iteration(rec(r), max);
        }
        case \min-max-iteration(r, min, max): {
            precedence = 6;
            regex = \min-max-iteration(rec(r), min, max);
        }
        case optional(r): {
            precedence = 6;
            regex = optional(rec(r, true)); // Prevent accidental reluctant operators by adding brackets to groups with the same precedence
        }

        case never(): ;
        case empty(): ;
        case always(): ;
        case character(_): ;
        case eol(): ;
        case sol(): ;
        case mark(tags, r): {
            <regex, precedence> = addRegexBracketsRec(r);
            regex = mark(tags, regex);
        }
        case meta(r, m): {
            <regex, precedence> = addRegexBracketsRec(r);
            regex = meta(regex, m);
        }

        default: {
            println("Missed a case in addRegexBracketsRec: <regex>");
        }
    }

    return <regex, precedence>;
}