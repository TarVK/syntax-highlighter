module testing::psnfaTest

import IO;
import ParseTree;

import regex::Regex;
import regex::RegexSyntax;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::PSNFATools;
import regex::NFASimplification;
import regex::RegexToPSNFA;
import regex::PSNFAToRegex;
import Visualize;

NFA[State] nfaTest() {
    // regex = parseRegexReduced("([a-n]\>a)+");
    // regex = parseRegexReduced("(a!\>(b|a+))*");
    // regex = parseRegexReduced("([a-o]\>([a-z]{3}!\>ok))*");
    // regex = parseRegexReduced("([a-o]\>[a-z]{3}!\>ok)*");
    // regex = parseRegexReduced("((\>(a{5})*(a|b){4}b)a{4})*b*c");
    // regex = parseRegexReduced("a{7}");
    // regex = parseRegexReduced("(something|somethingElse|more|stuff)!\<[a-z]+!\>(stuff|orange|crap)");
    // regex = parseRegexReduced("a!\>(aa)+b");
    // regex = parseRegexReduced("\\(something|somethingElse|more|stuff)");
    // regex = parseRegexReduced("[a-z]*-$e");
    // regex = parseRegexReduced("[a-d]\>(shit(![a-c]*)!\>.)");
    // regex = parseRegexReduced("[a-d]!\>(shit!\>.)");
    // regex = parseRegexReduced("(\<keyword\>sh.*it|(\<string\>stuff))");
    // regex = parseRegexReduced("[a-z]!\<[a-z]+!\>[a-z]");
    // regex = parseRegexReduced("(\<h\>.*)h(\<t\>.*)");
    regex = parseRegexReduced("((\<cg1\>.{3})\<(\<cg2\>h)h)*");
    // regex = parseRegexReduced("(\<cg1\>.|.)*b");
    // regex = parseRegexReduced("((\<t\>a)!\>(b|a+))*");
    // regex = parseRegexReduced("a*!\>b");
    // regex = parseRegexReduced("(\<t\>.)\\a");
    return regexToPSNFA(regex); 
    // return removeUnreachable(relabelSetPSNFA(convertPSNFAtoDFA(regexToPSNFA(regex), {}))); 
}

NFA[State] simplifyTest() {
    regex = parseRegexReduced("-(something|somethingElse|more|stuff)");
    n = regexToPSNFA(regex);
    m = relabelSetPSNFA(removeEpsilon(<n.initial, {<from, (on==matchStart() || on==matchEnd()) ? epsilon() : on, to> | <from, on, to><-n.transitions}, n.accepting, ()>));
    k = <simple("in"), {<simple("in"), epsilon(), m.initial>} + {<f, epsilon(), simple("fi")> | f <- m.accepting} + m.transitions, {simple("fi")}, ()>;
    return transitionsToRegex(k);
}

NFA[State] transformTest() {
    regex = parseRegexReduced("sh.*it|stuff");
    return regexToPSNFA(regex); 
}

NFA[State] reservationTest() {
    // regex = parseRegexReduced("[a-z]!\<(([a-z]+)\\(hoi|bye))!\>[a-z]");
    regex1 = "[a-z]!\<[a-z]+!\>[a-z]\\(hoi|bye)";
    regex2 = "(!\>([a-z]!\<(hoi|bye)))([a-z]!\<([a-z]+)!\>[a-z])";

    return difference(regex1, regex2);
}

NFA[State] scopeTest() {
    regex1 = "(\<hoi\>hel)(\<hoi\>lo)";
    regex2 = "(\<hoi\>he(\>(l)).lo)";

    // nfa1 = regexToPSNFA(parseRegexReduced(regex1));
    // nfa2 = regexToPSNFA(parseRegexReduced(regex2));
    // tagsUniverse = {*tagsClass | character(char, tagsClass) <- nfa1.transitions<1>};
    // return invertPSNFA(nfa2, tagsUniverse);
    return difference(regex1, regex2);
}

NFA[State] difference(str regex1, str regex2) {
    nfa1 = regexToPSNFA(parseRegexReduced(regex1));
    nfa2 = regexToPSNFA(parseRegexReduced(regex2));
    // return differencePSNFA(nfa1, nfa2);
    return simplify(differencePSNFA(nfa1, nfa2));
}

tuple[NFA[State], NFA[State]] minimizeTest() { 
    // This test only makes sense if minimization is disabled in the regexToPSNFA function
    
    regex = parseRegexReduced("([a-o]\>[a-z]{3}!\>ok)*");
    // regex = parseRegexReduced("h(o|e)i");
    nfa = regexToPSNFA(regex); 

    minimized = minimize(nfa);

    return <nfa,  relabelIntPSNFA(relabel(minimized))>;
}

NFA[State] simplify(NFA[State] n) = relabelIntPSNFA(relabel(removeDuplicates(removeEpsilon(removeUnreachable(n)))));

void main() {
    nfa = minimizeTest();

    // nfaText = visualizePSNFA(relabel(nfa));
    // loc pos = |project://syntax-highlighter/outputs/nfa.txt|;
    // writeFile(pos, "<nfaText>");
    visualize(insertPSNFADiagrams(nfa));
}