module testing::subtractionRemovalTest

import IO;
import ParseTree;

import mapping::intermediate::scopeGrammar::removeRegexSubtraction;
import mapping::intermediate::scopeGrammar::cleanupRegex;
import conversion::util::RegexCache;
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

void testRemoval(str regexText, bool convertable) {
    regex = parseRegexReduced(regexText);
    <converted, isEqual> = removeRegexSubtraction(regex);
    convertedText = stringify(cleanupRegex(removeRegexCache(converted)));

    if(!isEqual) {
        inRegex = subtractPSNFA(regexToPSNFA(regex), regexToPSNFA(converted));
        inConverted = subtractPSNFA(regexToPSNFA(converted), regexToPSNFA(regex));

        minimizedInRegex = minimizeUnique(inRegex);
        minimizedInConverted = minimizeUnique(inConverted);

        visualize(insertPSNFADiagrams(<
            regexText,
            convertedText,
            convertable == isEqual,
            minimizedInRegex,
            minimizedInConverted
        >));
    } else {
        visualize(insertPSNFADiagrams(<
            regexText,
            convertedText,
            convertable == isEqual
        >));
    }
}

void main() {
    // testRemoval("A([a-z]*\\(if))", true);
    // testRemoval("[a-z]*\\(if)", false);
    // testRemoval("([a-z]*(!\>[a-z]))\\(if)", true);
    // testRemoval("([a-z]*!\>[a-z])\\(if)", true);
    // testRemoval("([a-z]*\\(if))(!\>[a-z])", true);
    // testRemoval("([a-z]*\\(if))!\>[a-z]", true);
    // testRemoval("([a-z]*\>[0-9])\\(if)", true);
    // testRemoval("([a-z]*\>[a-z])\\(if)", false);
    // testRemoval("[a-z]!\<([a-z]*\\(if))", true);
    // testRemoval("[a-z]!\<([a-z]*\\(if|something|long|else|for))", true);
    // testRemoval("([a-z]+\\(shit))([0-9]+\\(19))", false); // Requires negative lookarounds from 2 sides: (?!shit[0-9]+)([a-z]+[0-9]+)(?<!([a-z]+19))
    // testRemoval("(([a-z]*\>[0-9])\\(if))|[0-9]*", true);
    testRemoval("smth\>(([a-z]*!\>[a-z])\\(if))", true);
}