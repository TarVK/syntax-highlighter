module conversionGrammar::regexConversion::RegexConversion

import Set;
import Relation;
import Map;
import List;
import IO;

import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::unionRegexes;
import regex::RegexToPSNFA;
import regex::Regex;
import regex::PSNFATools;


@doc {
    Combines productions into regular expressions in the given grammar
}
ConversionGrammar convertToRegularExpressions(ConversionGrammar grammar) {
    productions = index(grammar.productions);
    for(nonTerminal <- productions) {
        nonTerminalProductions = productions[nonTerminal];
        combined = unionRegexes(nonTerminalProductions);
        if(size(combined) < size(nonTerminalProductions)) {
            productions[nonTerminal] = combined;
        }
    }

    return convGrammar(grammar.\start, toRel(productions));
}