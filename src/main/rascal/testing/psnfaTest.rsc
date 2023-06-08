module testing::psnfaTest

import IO;
import ParseTree;

import regex::Regex;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFASimplification;
import regex::RegexToPSNFA;


void main() {
    // regex = parseRegexNormalized("([a-n]\>a)+");
    // regex = parseRegexNormalized("(a!\>(b|a+))*");
    // regex = parseRegexNormalized("([a-o]\>[a-z]{3}!\>ok)*");
    // regex = parseRegexNormalized("((\>(a{5})*(a|b){4}b)a{4})*b*c");
    // regex = parseRegexNormalized("a{7}");
    regex = parseRegexNormalized("(something|somethingElse|more|stuff)!\<[a-z]+!\>(stuff|orange|crap)");
    // regex = parseRegexNormalized("(!\>something|somethingElse|more|stuff)[a-z]+");
    nfa = regexToPSNFA(regex);

    
    nfaText = visualize(relabel(nfa));
    loc pos = |project://syntax-highlighter/outputs/nfa.txt|;
    writeFile(pos, "<nfaText>");
}