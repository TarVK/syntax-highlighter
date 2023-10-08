module determinism::check::checkExtensionOverlap

import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import regex::PSNFASimplification;
import regex::RegexTypes;
import regex::PSNFA;
import regex::PSNFATools;
import regex::PSNFACombinators;
import regex::regexToPSNFA;
import regex::NFA;
import regex::util::charClass;
import Warning;

@doc {
    Checks whether the grammar contains any regular expressions that can match a word as well as an extension of the same word
}
list[Warning] checkExtensionOverlap(ConversionGrammar grammar) {
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
        rNfa <- regexes,
        <r, prods> := regexes[rNfa],
        just(nfa) := doesSelfOverlap(r)
    ) 
        out += extensionOverlap(r, prods, nfa);

    return out;
}

Maybe[NFA[State]] doesSelfOverlap(Regex r) {
    nfa = regexToPSNFA(r);

    // The language followed by any non-empty word
    extension = getExtensionNFA(concatPSNFA(nfa, charPSNFA(anyCharClass())));
    
    overlap = minimizeUnique(productPSNFA(nfa, extension, true));
    if(!isEmpty(overlap)) 
        return just(overlap);
    return nothing();
}