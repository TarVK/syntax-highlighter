module testing::regexOverlapTest

import IO;
import ParseTree;
import util::Maybe;

import regex::Regex;
import regex::RegexSyntax;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::PSNFATools;
import regex::NFASimplification;
import regex::regexToPSNFA;
import regex::PSNFAToRegex;
import Visualize;

@doc {
    Checks whether an extension of rb overlaps with ra. I.e. whether a prefix of ra could also be matched by rb. 
}
Maybe[NFA[State]] getOverlap(Regex ra, Regex rb) {
    nfaA = regexToPSNFA(ra);
    nfaB = regexToPSNFA(rb);
    extensionB = getExtensionNFA(nfaB);
    overlap = productPSNFA(nfaA, extensionB, true);
    if(!isEmpty(overlap)) 
        return just(overlap);
    return nothing();
}

void main() {
    regex1 = parseRegexReduced("%");
    regex2 = parseRegexReduced("$$");

    // println(getOverlap(regex1, regex2));
    // println(getOverlap(regex2, regex1));
    
    nfa = regexToPSNFA(regex2); 
    visualize(insertPSNFADiagrams(nfa));
}
