module determinism::check::checkAmbiguity

import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import regex::NFA;
import regex::PSNFASimplification;
import regex::Regex;
import regex::PSNFA;
import regex::regexToPSNFA;
import regex::detectTagAmbiguity;
import Warning;

@doc {
    Checks whether the give grammar contains any regular expressions that can match the same word with multiple different scope assignments
}
list[Warning] checkAmbiguity(ConversionGrammar grammar) {
    list[Warning] out = [];

    map[NFA[State], tuple[Regex, set[ConvProd]]] regexes = ();
    for(
        <_, p:convProd(_, parts)> <- grammar.productions,
        regexp(r) <- parts
    ) {
        nfa = regexToPSNFA(r);
        if(nfa in regexes) regexes[nfa][1] += {p};
        else               regexes[nfa] = <r, {p}>;
    }

    for(
        nfa <- regexes,
        <r, prods> := regexes[nfa],
        just(getAmbiguity) := getTagAmbiguity(regexToPSNFA(r))
    ) 
        out += ambiguity(r, prods, relabelIntPSNFA(relabel(getAmbiguity())));

    return out;
}