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
    r = parseRegexReduced("(((\<t\>a)|b)+c)+");

    r = regexToSingleCaptureRegex(r);
    nfa = regexToPSNFA(r);
    return <r, nfa>;
}

void main() {
    // visData = intersectionTest();
    visData = lastCaptureTest();

    visualizeGrammars(visData);
}