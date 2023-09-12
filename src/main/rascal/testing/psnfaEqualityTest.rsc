module testing::psnfaEqualityTest

import IO;
import regex::Regex;
import regex::RegexToPSNFA;
import regex::PSNFA;
import regex::PSNFATools;
import regex::PSNFASimplification;
import Visualize;



void main() {
    // // regex = parseRegexReduced("([a-z]!\<[a-z][a-z0-9]*!\>[a-z0-9])\\(([a-z]!\<)(for|if|in)(!\>[a-z0-9]))");
    // // regex = parseRegexReduced("((\<k.stzff,ok.staff\>[a-z])|(\<arange\>[a-z]))(\<cool\>[b-d])|(\<k.stuff\>[a-z](\<cool\>[b-d]))");
    // regex = parseRegexReduced("([a-z]([a-z]|![a-z])?|![a-z]([a-b]|![a-b])?)*");
    // println("start");
    // nfa = regexToPSNFA(regex);
    // println("finish");

    // visualize(<
    //     insertPSNFADiagrams(nfa)
    // >);

    regex1 = parseRegexReduced("([a-z]!\<[a-z][a-z0-9]*!\>[a-z0-9])\\(([a-z]!\<)(for|if|in)(!\>[a-z0-9]))");
    regex2 = parseRegexReduced("(!\>([a-z]!\<)(if|for|in)(!\>[a-z0-9]))([a-z]!\<[a-z][a-z0-9]*!\>[a-z0-9])");
    nfa1 = regexToPSNFA(regex1);
    nfa2 = regexToPSNFA(regex2);
    visualize(insertPSNFADiagrams(<
        nfa1,
        nfa2,
        nfa1 == nfa2
    >));
}