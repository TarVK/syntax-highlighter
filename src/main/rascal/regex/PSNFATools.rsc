@synopsis{PSNFA tools for analyzing properties}
@description{
    Utilities to determine partial overlap between different PSNFA languages
}

module regex::PSNFATools

import IO;
import util::Maybe;
import ParseTree;

import regex::util::charClass;
import regex::Regex;
import regex::regexToPSNFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFA;
import regex::NFASimplification;
import regex::Tags;

@doc {
    Checks whether the two given NFAs define the same language.
    If moduloTags is specified, the tag data is ignored.
}
bool equals(NFA[State] a, NFA[State] b)
    = equals(a, b, false);
bool equals(NFA[State] a, NFA[State] b, bool moduloTags) {
    if (a == b) return true;

    // This check is quicker than the subtraction check, hence doing this first might speed things up since majority of calls return false, this check can be left out if it ends up making things slower
    if(isEmpty(productPSNFA(a, b, moduloTags))) return false;
    
    inANotB = moduloTags ? strongSubtractPSNFA(a, b) : subtractPSNFA(a, b);
    if(!isEmpty(inANotB)) return false;

    inBNotA = moduloTags ? strongSubtractPSNFA(b, a) : subtractPSNFA(b, a);
    if(!isEmpty(inBNotA)) return false;

    return true;
}

@doc {
    Checks whether two given regular expressions define the same language.
    If moduloTags is specified, the tag data is ignored.
}
bool equals(Regex a, Regex b)
    = equals(a, b, false);
bool equals(Regex a, Regex b, bool moduloTags) {
    aNFA = regexToPSNFA(a);
    bNFA = regexToPSNFA(b);
    if(!moduloTags) return aNFA == bNFA; // regex nfas are minimized and normalized such that every language has a unique minimal+normal NFA

    /*
        Results after adding nfa normalization and using it for equality checking compared to before:
        Normalized:
        5:48, 5:04 with expandFollow
        2:19, 2:14 without expandFollow

        Regular:
        4:20, 4:19, with expandFollow
        3:01, 3:03, without expandFollow

        So if we don't do many (non-cached) regex to psnfa conversions, it seems the extra initialization time is worth it for the faster equivalence checking
    */

    return equals(aNFA, bNFA, moduloTags);
}


@doc {
    Checks whether the language of sub is a subset of the langauge of super.
    if moduloTags is specified, the tag data is ignored.
}
bool isSubset(Regex sub, Regex super) 
    = isSubset(sub, super, false);
bool isSubset(Regex sub, Regex super, bool moduloTags) 
    = isSubset(regexToPSNFA(sub), regexToPSNFA(super), moduloTags);
bool isSubset(NFA[State] sub, NFA[State] super)
    = isSubset(sub, super, false);
bool isSubset(NFA[State] sub, NFA[State] super, bool moduloTags) {
    if (sub == super) return true;
    
    inSubNotSuper = moduloTags ? strongSubtractPSNFA(sub, super) : subtractPSNFA(sub, super);
    return isEmpty(inSubNotSuper);
}

@doc {
    Computes the difference between the two PSNFAs, which includes all words in one and not the other
}
NFA[State] differencePSNFA(NFA[State] a, NFA[State] b) {
    if (a == b) return neverPSNFA();
    
    inANotB = subtractPSNFA(a, b);
    inBNotA = subtractPSNFA(b, a);
    return unionPSNFA(inANotB, inBNotA);
}

@doc {
    Checks whether the given regex/nfa accepts an empty string, in some context (I.e. the emtpy string possible with lookahead/behind restrictions)
}
bool acceptsEmpty(Regex r) = acceptsEmpty(regexToPSNFA(r));
bool acceptsEmpty(NFA[State] n) 
    = !isEmpty(productPSNFA(emptyPSNFA(), n, true));

@doc {
    Checks whether the given regex/nfa accepts an empty string in every context, (I.e. the empty string without any lookahead/behind restrictions)
}
bool alwaysAcceptsEmpty(Regex r) = alwaysAcceptsEmpty(regexToPSNFA(r));
bool alwaysAcceptsEmpty(NFA[State] n)
    = isSubset(emptyPSNFA(), n);

@doc {
    Creates a NFA that accepts all the original words, as well as any extensions of those words
}
NFA[State] getExtensionNFA(NFA[State] n)
    = getExtensionNFA(n, false);
NFA[State] getExtensionNFA(NFA[State] n, bool strict) 
    = concatPSNFA(
        n, 
        strict 
            ? concatPSNFA(
                charPSNFA(anyCharClass()), 
                alwaysPSNFA()
            ) 
            : alwaysPSNFA()
    );

@doc {
    Checks whether two given NFAs overlap, I.e. if one can be extended by 0 or more characters to match a word in the other. This ignores presence of tags

    If extension is set to true, the test ignores words that are matched by both nfas, and only considers words that can be extended to a word in another nfa

    If direcitonal is set to true, the test checks if b can be extended with characters to overlap a. Otherwise it's checked both ways
}
bool overlaps(NFA[State] a, NFA[State] b)
    = overlaps(a, b, false, false);
bool overlaps(NFA[State] a, NFA[State] b, bool directional, bool extension) {
    extensionB = getExtensionNFA(b, extension);
    overlapB = productPSNFA(a, extensionB, true);
    if(!isEmpty(overlapB)) return true;
    
    if(directional) return false;

    extensionA = getExtensionNFA(a, extension);
    overlapA = productPSNFA(b, extensionA, true);
    if(!isEmpty(overlapA)) return true;

    return false;
}

@doc {
    Uses the regular expression's PSNFA to check if the given regular expression can match any text that includes a newline
}
bool containsInternalNewline(Regex regex) {
    n = regexToPSNFA(regex);
    <_, mainStates, _> = getPSNFApartition(n);
    transitions = n.transitions[mainStates]<0>;

    newline = [range(10, 10)];
    hasNewline = TransSymbol:character(cc, _) <- transitions && size(fIntersection(cc, newline))>0;
    return hasNewline;
}