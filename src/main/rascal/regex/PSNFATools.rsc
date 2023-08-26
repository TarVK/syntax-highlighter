@synopsis{PSNFA tools for analyzing properties}
@description{
    Utilities to determine partial overlap between different PSNFA languages
}

module regex::PSNFATools

import IO;
import util::Maybe;

import regex::Regex;
import regex::RegexToPSNFA;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::NFA;
import regex::NFASimplification;
import regex::Tags;

// Would prefer to not import this here, see if we can get around this
import conversion::util::RegexCache;

@doc {
    Checks whether the two given NFAs define the same language
}
bool equals(NFA[State] a, NFA[State] b) {
    if (a == b) return true;
    
    inANotB = subtractPSNFA(a, b);
    inBNotA = subtractPSNFA(b, a);
    return isEmpty(inANotB) && isEmpty(inBNotA);
}

@doc {
    Checks whether two given regular expressions define the same language
}
bool equals(Regex a, Regex b) {
    aNFA = regexToPSNFA(a);
    bNFA = regexToPSNFA(b);
    return equals(aNFA, bNFA);
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
    Checks whether the language of sub is a subset of the langauge of super.
    if moduloTags is specified, the tag data is ignored.
    Stores part of the computation in the cache, to speed up consecutive checks
}
tuple[SubtractCache, bool] isSubset(Regex sub, Regex super, SubtractCache cache) 
    = isSubset(sub, super, false, cache);
tuple[SubtractCache, bool] isSubset(Regex sub, Regex super, bool moduloTags, SubtractCache cache) 
    = isSubset(regexToPSNFA(sub), regexToPSNFA(super), moduloTags, cache);
tuple[SubtractCache, bool] isSubset(NFA[State] sub, NFA[State] super, SubtractCache cache)
    = isSubset(sub, super, false, cache);
tuple[SubtractCache, bool] isSubset(
    NFA[State] sub, 
    NFA[State] super, 
    bool moduloTags, 
    SubtractCache cache
) {

    TagsClass universe = moduloTags 
        ? {{}}
        : {*tagsClass | character(char, tagsClass) <- sub.transitions<1>};
    Maybe[TagsClass] cacheUniverse = moduloTags ? nothing() : just(universe);

    NFA[State] inverted;
    if(<super, cacheUniverse> in cache) {
        inverted = cache[<super, cacheUniverse>];
    } else {
        if(moduloTags)
            super = replaceTagsClasses(super, {{}});

        inverted = invertPSNFA(super, universe);
        // inverted = relabelSetPSNFA(minimizeDFA(inverted)); // TODO: check if it matters that inverted's transitions are not complete (but are disjoint, like a DFA)
        cache[<super, cacheUniverse>] = inverted;
    }
    
    product = productPSNFA(sub, inverted, moduloTags);
    return <cache, isEmpty(product)>;

    // return <cache, isSubset(sub, super, moduloTags)>;
}
alias SubtractCache = map[tuple[NFA[State], Maybe[TagsClass]], NFA[State]];



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
NFA[State] getExtensionNFA(NFA[State] n) = concatPSNFA(n, alwaysPSNFA());

@doc {
    Obtains PSNFAs o and e such that,
    L(no) = {(p, w, s) | (p, w, s) ∈ L(n) ∧ (∃ wp, ws . w = wp ws ∧ (p, wp, ws s) ∈ L(m))}
    L(me) = {(p, w, s) | ∃ (mp, mw, ms) ∈ L(m) . p = mp mw ∧ w s = ms ∧ (mp, mw w, s) ∈ L(n)}

    I.e. no specifies all words in n, such that m contains a prefix of said word,
    and me specifies all extension words t such that there exists a word h in m for which the concatenation ht is in n (a word in m can be extended using e to be part of n). 

    If these languages are empty, nothing is returned instead
}
Maybe[tuple[NFA[State] no, NFA[State] me]] getPrefixOverlap(NFA[State] n, NFA[State] m) {
    // TODO: implement
}