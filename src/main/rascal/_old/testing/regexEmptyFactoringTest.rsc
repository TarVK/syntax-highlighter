module testing::regexEmptyFactoringTest

import IO;
import ParseTree;
import Grammar;
import Set;

import conversion::util::RegexCache;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import regex::util::charClass;
import regex::Regex;
import regex::RegexSyntax;
import regex::NFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::PSNFATools;
import regex::NFASimplification;
import regex::regexToPSNFA;
import regex::PSNFAToRegex;
import regex::RegexTransformations;
import Visualize;

alias Result = tuple[
    Grammar overview,
    map[str, Regex] regexes,
    map[str, NFA[State]] automata,
    set[str] errors
];

Result testRegex(str regexText) {
    regex = parseRegexReduced(regexText);
    nfa = regexToPSNFA(regex);

    <nonEmptyR, emptyR, emptyRestrR> = factorOutEmpty(regex);

    set[str] problems = {};
    
    combinedRegex = Regex::alternation(nonEmptyR, Regex::alternation(emptyR, emptyRestrR));
    combinedNfa = regexToPSNFA(combinedRegex);
    if(!equals(nfa, combinedNfa))
        problems += "Languages are not equivalent";

    if(acceptsEmpty(nonEmptyR))
        problems += "The non-empty regex accepts an empty string";
    
    if(!(emptyR == never() || cached(Regex::empty(), _, _) := emptyR))
        problems += "Empty is not equal to empty() or never()";

    emptyRestrNfa = regexToPSNFA(emptyRestrR);
    anyNonEmptyWordNfa = iterationPSNFA(charPSNFA(anyCharClass()));
    acceptedWords = productPSNFA(anyNonEmptyWordNfa, emptyRestrNfa, true);
    if(!isEmpty(acceptedWords)) 
        problems += "The restricted empty accepts non-empty words";

    return <
        fromConversionGrammar(convGrammar(
            sort("input"),
            {
                <sort("input"), convProd(sort("input"), [regexp(regex)], {})>,
                <sort("non-empty"), convProd(sort("non-empty"), [regexp(nonEmptyR)], {})>,
                <sort("empty"), convProd(sort("empty"), [regexp(emptyR)], {})>,
                <sort("emptyRestr"), convProd(sort("emptyRestr"), [regexp(emptyRestrR)], {})>
            }
        )),
        (
            "input": regex,
            "non-empty": nonEmptyR,
            "empty": emptyR,
            "emptyRestr": emptyRestrR
        ),
        (
            "input": nfa,
            "output": combinedNfa,
            "emptyRestr": emptyRestrNfa,
            "nonEmpty": regexToPSNFA(nonEmptyR)
        ),
        problems
    >;
}

void showRegexTest(str expr) {
    visualize(insertPSNFADiagrams(testRegex(expr)));
}

set[Result] testAll(set[str] expressions) {
    set[Result] problems = {};
    for(expr <- expressions) {
        result = testRegex(expr);
        if (size(result.errors)>0) {
            problems += result;
        }
    }

    return problems;
}

void showTestAll(set[str] expressions) {
    visualize(insertPSNFADiagrams(testAll(expressions)));
}



void main() {
    showTestAll({
        "a?",
        "a?bc?",
        "a?b?c?",
        "(a?b?c?)\>b",
        "(a?)*",
        "(a?\>z)+",
        "a?!\>z",
        "(a?!\>z)+",
        "[a-z]*\\stuff",
        "[a-z]+\\stuff",
        "[a-z]+\\stu(x\>o)|(x?|(b?\>hello)+)+",
        "((\>(\<k\>b))|[a-z])+",
        "((\>(\<k\>b))|(\>(\<d\>b))|[a-z])*"
    });
    // showRegexTest("[a-z]+\\stu(x\>o)|(x?|(b?\>hello)+)+");
}