module testing::lastCaptureTest

import IO;

import testing::util::visualizeGrammars;
import regex::Regex;
import regex::regexToPSNFA;
import regex::regexToSingleCaptureRegex;
import regex::PSNFA;

tuple[Regex, NFA[State]] intersectionTest() {
    r = parseRegexReduced("stuff&(!t|(\<k\>(\<s\>t)))*");
    nfa = regexToPSNFA(r);
    return <r, nfa>;
}

tuple[Regex, NFA[State]] lastCaptureTest() {
    // r = parseRegexReduced("(\<t\>.)+");
    // r = parseRegexReduced("((\<t\>a)|p)+");
    // r = parseRegexReduced("((\<t\>aa)|p)+");
    // r = parseRegexReduced("((\<t\>a)|(\<u\>p))*");
    // r = parseRegexReduced("((\<t\>a)(\<u\>p))+");
    // r = parseRegexReduced("(((\<t\>a)|p)((\<u\>b)|q))+");
    // r = parseRegexReduced("((\<t\>a)(b|(\<t2\>c)))+");
    // r = parseRegexReduced("(b|(\<t2\>c))+");
    // r = parseRegexReduced("(((\<t\>a)|b)+c)+");
    // r = parseRegexReduced("(b|(\<t1\>(a+)))+");
    // r = parseRegexReduced("(b|(\<t1\>((\<t2\>a)+)))+");
    // r = parseRegexReduced("(b|(\<t1\>(((\<t2\>a)|(\<t3\>c))+)))+");
    r = parseRegexReduced("(a|(\<t1\>a)(\<t2\>a))+"); // Does not work

    r = regexToSingleCaptureRegex(r);
    nfa = regexToPSNFA(r);
    return <r, nfa>;
}

void testEquivalance() {
    rel[str, str] equivalences = {
        <"(\<t\>a+)", "(\<t\>(a|a)+)">,
        <"((\<t\>a)+)+", "(\<t\>a)+">,
        <"(!\>b)(\<t\>b)+", "$0">,
        <"((\<t2\>b)|(\<t1\>b))+", "b*(\<t1\>b)(b*(\<t2\>b))?|b*(\<t2\>b)(b*(\<t1\>b))?">
    };
    rel[str, str] nonEquivalences = {
        <"(\<t\>a)+", "(\<t\>a+)">,
        <"((\<t1\>a)|(\<t2\>a))+", "(\<t1\>a)+|(\<t2\>a)+">
    };

    tests = {<a, b, true> | <a, b> <- equivalences} + {<a, b, false> | <a, b> <- nonEquivalences};
    for(<r1Text, r2Text, shouldEqual> <- tests) {
        r1 = regexToSingleCaptureRegex(parseRegexReduced(r1Text));
        r2 = regexToSingleCaptureRegex(parseRegexReduced(r2Text));
        nfa1 = regexToPSNFA(r1);
        nfa2 = regexToPSNFA(r2);
        equals = nfa1 == nfa2;
        if(equals != shouldEqual) {
            visualizeGrammars(<
                <
                    r1Text,
                    r1,
                    nfa1 
                >,
                <
                    r2Text,
                    r2,
                    nfa2
                >,
                shouldEqual
            >);
            throw "error";
        }
    }
}

void main() {
    // visData = intersectionTest();
    visData = lastCaptureTest();

    visualizeGrammars(visData);

    // testEquivalance();
}