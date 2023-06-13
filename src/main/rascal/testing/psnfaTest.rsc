module testing::psnfaTest

import IO;
import ParseTree;

import regex::Regex;
import regex::RegexSyntax;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFASimplification;
import regex::RegexToPSNFA;
import regex::PSNFAToRegex;

NFA[State] nfaTest() {
    // regex = parseRegexNormalized("([a-n]\>a)+");
    // regex = parseRegexNormalized("(a!\>(b|a+))*");
    // regex = parseRegexNormalized("([a-o]\>[a-z]{3}!\>ok)*");
    // regex = parseRegexNormalized("((\>(a{5})*(a|b){4}b)a{4})*b*c");
    // regex = parseRegexNormalized("a{7}");
    // regex = parseRegexNormalized("(something|somethingElse|more|stuff)!\<[a-z]+!\>(stuff|orange|crap)");
    // regex = parseRegexNormalized("a!\>(aa)+b");
    // regex = parseRegexNormalized("-(something|somethingElse|more|stuff)");
    // regex = parseRegexNormalized("[a-z]*-$e");
    // regex = parseRegexNormalized("[a-d]\>(shit(![a-c]*)!\>.)");
    // regex = parseRegexNormalized("[a-d]!\>(shit!\>.)");
    // regex = parseRegexNormalized("sh.*it|stuff");
    regex = parseRegexNormalized("[a-z]!\<[a-z]+!\>[a-z]");
    return regexToPSNFA(regex); 
}

NFA[State] simplifyTest() {
    regex = parseRegexNormalized("-(something|somethingElse|more|stuff)");
    n = regexToPSNFA(regex);
    m = relabelSetPSNFA(removeEpsilon(<n.initial, {<from, (on==matchStart() || on==matchEnd()) ? epsilon() : on, to> | <from, on, to><-n.transitions}, n.accepting>));
    k = <simple("in"), {<simple("in"), epsilon(), m.initial>} + {<f, epsilon(), simple("fi")> | f <- m.accepting} + m.transitions, {simple("fi")}>;
    return transitionsToRegex(k);
}

NFA[State] transformTest() {
    regex = parseRegexNormalized("sh.*it|stuff");
    return regexToPSNFA(regex); 
}

NFA[State] reservationTest() {
    // regex = parseRegexNormalized("[a-z]!\<(([a-z]+)\\(hoi|bye))!\>[a-z]");
    regex1 = parseRegexNormalized("[a-z]!\<[a-z]+!\>[a-z]\\(hoi|bye)");
    regex2 = parseRegexNormalized("(!\>([a-z]!\<(hoi|bye)))([a-z]!\<([a-z]+)!\>[a-z])");

    nfa1 = regexToPSNFA(regex1);
    nfa2 = regexToPSNFA(regex2);

    inNfa1NotNfa2 = subtractPSNFA(nfa1, nfa2);
    inNfa2NotNfa1 = subtractPSNFA(nfa2, nfa1);
    return removeUnreachable(unionPSNFA(inNfa1NotNfa2, inNfa2NotNfa1));
}

void main() {
    nfa = reservationTest();


    nfaText = visualize(relabel(nfa));
    loc pos = |project://syntax-highlighter/outputs/nfa.txt|;
    writeFile(pos, "<nfaText>");
}