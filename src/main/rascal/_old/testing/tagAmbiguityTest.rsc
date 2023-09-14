module testing::tagAmbiguityTest

import regex::Regex;
import regex::PSNFA;
import regex::detectTagAmbiguity;
import regex::RegexToPSNFA;
import regex::NFASimplification;
import regex::PSNFACombinators;
import Visualize;

void testAmbiguity(set[str] ambiguous, set[str] unambiguous) {
    set[NFA[State]] shouldBeAmbiguous = {};
    set[NFA[State]] shouldBeUnambiguous = {};

    for(amb <- ambiguous) {
        regex = parseRegexReduced(amb);
        nfa = regexToPSNFA(regex);
        if(!isTagAmbiguous(nfa)){
            shouldBeAmbiguous += nfa;
        }
    }
    for(unamb <- unambiguous) {
        regex = parseRegexReduced(unamb);
        nfa = regexToPSNFA(regex);
        if(isTagAmbiguous(nfa)){
            shouldBeUnambiguous += nfa;
        }
    }

    visualize(insertPSNFADiagrams(<
        shouldBeAmbiguous,
        shouldBeUnambiguous
    >));
}

void testAmbiguity(str regexText) {
    regex = parseRegexReduced(regexText);
    nfa = regexToPSNFA(regex);
    isAmbiguous = isTagAmbiguous(nfa);


    d = removeUnreachable(convertPSNFAtoDFA(nfa));
    taglessN = replaceTagsClasses(d, {{}});

    visualize(insertPSNFADiagrams(<
        isAmbiguous,
        nfa,
        relabelSetPSNFA(d),
        relabelSetPSNFA(taglessN)
    >));
}

void main() {
    // testAmbiguity({
    //     "(\<a\>hoi)|(\<a\>h)oi",
    //     "(\<a\>hoi)|(\<b\>hoi)",
    //     "(\<a\>hoi)|hoi",
    //     "h((\<a\>oi)|(\<b\>oi))",
    //     "h((\<a\>h?oi)|(\<b\>oi))",
    //     "(\<a\>a)*a*"
    // }, {
    //     "(\<a\>hoi)|(\<a\>h)o",
    //     "(\<a\>hoi)|(\<a\>hoi)",
    //     "(\<a\>oi)|(\<b\>hoi)",
    //     "h((\<a\>oi)|(\<a\>oi))",
    //     "(\<a\>hoi)|(\<a\>h)(\<a\>oi)",
    //     "(\<a\>a)*ba*"
    // });
    testAmbiguity("(\<a\>hoi)|(\<a\>h)o");
}