module mapping::intermediate::scopeGrammar::removeRegexSubtraction

import List;
import IO;


import regex::PSNFATools;
import regex::regexToPSNFA;
import regex::RegexCache;
import regex::Regex;
import Scope;

data CaptureGroup = captureGroup(int id);

@doc {
    Attempts to replace subtraction by means of lookaheads, and checks whether it did so successfully. It assumes the input regex is in simplified form. 
}
tuple[
    Regex output, 
    bool equivalent
] removeRegexSubtraction(Regex regex) {
    if(/subtract(_, _) !:= regex) return <regex, true>;

    <lb, output, la, sub, equivalent> = removeRegexSubtractionRec(regex);

    <subtractedOutput, subEqual> = tryLookaround(lb, output, la, sub);
    return <subtractedOutput, equivalent && subEqual>;
}

@doc {
    Attempts to replace subtraction by means of lookaheads, and checks whether it did so successfully. It assumes the input regex is in simplified form. 

    Given an input regex, outputs:
    - Regex lb,
    - Regex out,
    - Regex la,
    - Regex sub,
    - bool equal

    such that:
    - equal => L(out\sub) = L(regex)
    - equal => L(out\(lb sub la)) = L(regex)
    - if regex does not contain any subtraction => equal
    - none of the output expressions contain subtractions

    Apart from that it gives no guarantees, but tries to add as much data as possible to lb, la and sub such that:
    - L((!>lb sub la)out) = L(regex)
    - or L(out(lb sub la !<)) = L(regex)
    But this can not be guaranteed
}
tuple[
    Regex lookbehind,
    Regex output, 
    Regex lookahead,
    Regex subtraction,
    bool equivalent
] removeRegexSubtractionRec(Regex regex) {
    Regex lb = empty();
    Regex output = regex;
    Regex la = empty();
    Regex sub = never();
    bool equivalent = true;

    Regex resolveRec(<lbRec, outputRec, laRec, subRec, eqRec>) {
        <outputWithSubtraction, lookaroundSuccess> = tryLookaround(lbRec, outputRec, laRec, subRec);
        if(!lookaroundSuccess || !eqRec) equivalent = false;
    
        return outputWithSubtraction;
    }

    switch(regex) {
        case subtract(r, newSub): {
            <rLB, r, rLA, rSub, rEq> = removeRegexSubtractionRec(r);
            newSub = resolveRec(removeRegexSubtractionRec(newSub));

            lb = rLB;
            output = r;
            la = rLA;
            sub = simplifiedAlternation(rSub, newSub);
        }

        case never(): ;
        case empty(): ;
        case always(): ;
        case character(_): ;
        case lookahead(r, newLA): {
            <rLB, r, rLA, rSub, rEq> = removeRegexSubtractionRec(r);
            newLA = resolveRec(removeRegexSubtractionRec(newLA));

            lb = rLB;
            output = lookahead(r, newLA);
            la = simplifiedConcatenation(rLA, lookahead(empty(), newLA));
            sub = simplifiedLookahead(rSub, newLA);
        }
        case lookbehind(r, newLB): {
            <rLB, r, rLA, rSub, rEq> = removeRegexSubtractionRec(r);
            newLB = resolveRec(removeRegexSubtractionRec(newLB));

            lb = simplifiedConcatenation(lookbehind(empty(), newLB), rLB);
            output = lookbehind(r, newLB);
            la = rLA;
            sub = simplifiedLookbehind(rSub, newLB);
        }
        case \negative-lookahead(r, newLA): {
            <rLB, r, rLA, rSub, rEq> = removeRegexSubtractionRec(r);
            newLA = resolveRec(removeRegexSubtractionRec(newLA));

            lb = rLB;
            output = \negative-lookahead(r, newLA);
            la = simplifiedConcatenation(rLA, \negative-lookahead(empty(), newLA));
            sub = simplifiedNegativeLookahead(rSub, newLA);
        }
        case \negative-lookbehind(r, newLB): {
            <rLB, r, rLA, rSub, rEq> = removeRegexSubtractionRec(r);
            newLB = resolveRec(removeRegexSubtractionRec(newLB));

            lb = simplifiedConcatenation(\negative-lookbehind(empty(), newLB), rLB);
            output = \negative-lookbehind(r, newLB);
            la = rLA;
            sub = simplifiedNegativeLookbehind(rSub, newLB);
        }
        case concatenation(h, t): {
            <hLB, h, hLA, hSub, hEq> = removeRegexSubtractionRec(h);
            <tLB, t, tLA, tSub, tEq> = removeRegexSubtractionRec(t);

            lb = isEmpty(h) ? simplifiedConcatenation(hLB, tLB) : hLB;
            output = concatenation(h, t);
            la = isEmpty(t) ? simplifiedConcatenation(hLA, tLA) : tLA;
            sub = simplifiedAlternation(simplifiedConcatenation(hSub, t), simplifiedConcatenation(h, tSub));
        }
        case alternation(o1, o2): {
            // TODO: try to make use of equivalence: (X \ Y) + Z = (X + Z) \ Y   (if L(Z) ∩ L(Y) = {})
            newO1 = resolveRec(removeRegexSubtractionRec(o1));
            newO2 = resolveRec(removeRegexSubtractionRec(o2));
            output = alternation(newO1, newO2);
        }
        case \multi-iteration(r): {
            newR = resolveRec(removeRegexSubtractionRec(r));
            output = \multi-iteration(newR);
        }
        case mark(tags, r): {
            <rLB, r, rLA, rSub, rEq> = removeRegexSubtractionRec(r);

            lb = rLB;
            output = mark(tags, r);
            la = rLA;
            sub = rSub;
        }

        case meta(r, _): return removeRegexSubtractionRec(r);
        default: {
            // Unsupported, shouldn't happen
            println("Missed a case in removeSubtraction implementation: <regex>");
        }
    }

    return <lb, output, la, sub, equivalent>;
}

bool isEmpty(lookahead(r, la)) = isEmpty(r);
bool isEmpty(\negative-lookahead(r, la)) = isEmpty(r);
bool isEmpty(lookbehind(r, lb)) = isEmpty(r);
bool isEmpty(\negative-lookbehind(r, lb)) = isEmpty(r);
bool isEmpty(meta(r, _)) = isEmpty(r);
bool isEmpty(empty()) = true;
default bool isEmpty(Regex r) = false;

/*
    Equivalences that the correctness of the algorithm relies on:

    - (X > Y) \ Z = (X > Y) \ (Z > Y):
        - (X !> Y) \ Z = (X !> Y) \ (Z !> Y)
        - (X < Y) \ Z = (X < Y) \ (X < Z)
        - (X !< Y) \ Z = (X !< Y) \ (X !< Z)        
    - (X \ Y) > Z = (X > Z) \ (Y > Z)
        - (X \ Y) !> Z = (X !> Z) \ (Y !> Z)
        - Z < (X \ Y) = (Z < X) \ (Z < Y)
        - Z !< (X \ Y) = (Z !< X) \ (Z !< Y)
    - (X \ Y) \ Z = X \ (Y + Z)

    TODO: prove correctness of these
    - (X \ Y) Z = (X Z) \ (Y Z):
        - Z (X \ Y) = (Z X) \ (Z Y)
    - X ($e > Y) = X > Y:
        - X ($e !> Y) = X !> Y
        - (Y < $e) X = Y < X
        - (Y !< $e) X = Y !< X

    Could also use:
        - (X \ Y) + Z = (X + Z) \ Y   (if L(Z) ∩ L(Y) = {})
*/

@doc {
    Combine the given lookbehind, lookahead, regex, and subtraction such that:
    - out contains no subtraction, assuming none of its inputs did
    - equal => L(regex\sub) = L(out)
}
tuple[Regex out, bool equivalent] tryLookaround(  
    Regex lb,
    Regex regex, 
    Regex la,
    Regex sub
) {
    if(sub==never()) return <regex, true>;

    regex = getCachedRegex(regex);
    
    spec = subtract(regex, sub);
    specNFA = regexToPSNFA(spec, false);

    sub = simplifiedConcatenation(lb, simplifiedConcatenation(sub, la));

    laApproach = getCachedRegex(concatenation(\negative-lookahead(empty(), sub), regex));
    laApproachNFA = regexToPSNFA(laApproach);
    if(equals(laApproachNFA, specNFA)) // We do nfa level equality checks, because the cached nfas aren't normalized for performance reasons
        return <laApproach, true>;
    
    lbApproach = getCachedRegex(concatenation(regex, \negative-lookbehind(empty(), sub)));
    lbApproachNFA = regexToPSNFA(lbApproach);
    if(equals(lbApproachNFA, specNFA))
        return <lbApproach, true>;

    return <laApproach, false>;
}