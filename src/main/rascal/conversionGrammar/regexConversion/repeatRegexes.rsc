module conversionGrammar::regexConversion::repeatRegexes

import Set;
import util::Maybe;
import IO;

import conversionGrammar::ConversionGrammar;
import regex::Regex;
import regex::Tags;
import regex::PSNFATools;
import conversionGrammar::RegexCache;
import Scope;

@doc {
    Tries to apply either of the repeat rules:
    ```
    A -> (<s> X!) A!
    A -> Y
    A -/> 
    ```
    => {Repetition-right}
    ```
    A -> (<s> X!*) Y
    ```
    and
    ```
    A -> A! (<s> X!)   
    A -> Y
    A -/> 
    ```
    => {Repetition-left}
    ```
    A -> Y (<s> X*)
    ```
}
Maybe[set[ConvProd]] repeatRegexes(Symbol sym, set[ConvProd] productions) {
    if(s:just(_) := repeatMultiLeftRegexes(sym, productions)) return s;
    if(s:just(_) := repeatLeftRegexes(sym, productions)) return s;
    if(s:just(_) := repeatMultiRightRegexes(sym, productions)) return s;
    if(s:just(_) := repeatRightRegexes(sym, productions)) return s;

    return nothing();
}

@doc {
    Tries to apply the left repeat rule: 
    ```
    A -> A! (<s> X!)   
    A -> Y
    A -/> 
    ```
    => {Repetition-left}
    ```
    A -> Y (<s> X*)
    ```
    Where Y is non-empty
}
Maybe[set[ConvProd]] repeatMultiLeftRegexes(Symbol sym, set[ConvProd] productions) {
    if({s:convProd(_, [regexp(fRegex)], _), r:convProd(_, [symb(lSym, []), regexp(rRegex)], _)} := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex)) {

        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;
        
        Regex newRegex;
        if(just(<firstRegex, firstTags>) := getScopelessRegex(fRegex), 
            firstTags == tags,
            equals(repeatRegex, firstRegex)) 
            newRegex = withTags(\multi-iteration(repeatRegex));
        else             
            newRegex = concatenation(
                            fRegex, 
                            alternation(
                                withTags(\multi-iteration(repeatRegex)),
                                empty()
                        ));

        return createNewProd(sym, newRegex, {s, r});
    }
    return nothing();
}

@doc {
    Tries to apply the left repeat rule: 
    ```
    A -> A! (<s> X!)   
    A ->
    A -/> 
    ```
    => {Repetition-left}
    ```
    A -> (<s> X*)
    ```
}
Maybe[set[ConvProd]] repeatLeftRegexes(Symbol sym, set[ConvProd] productions) {
    if({s:convProd(_, [], _), r:convProd(_, [symb(lSym, []), regexp(rRegex)], _)} := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex)) {

        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;

        return createNewProd(sym, withTags(alternation(
                            \multi-iteration(repeatRegex),
                            empty()
                        )), {s, r});
    }
    return nothing();
}

@doc {
    Tries to apply the right repeat rule: 
    ```
    A -> (<s> X!) A! 
    A -> Y
    A -/> 
    ```
    => {Repetition-right}
    ```
    A -> (<s> X*) Y
    ```
    Where Y is non-empty
}
Maybe[set[ConvProd]] repeatMultiRightRegexes(Symbol sym, set[ConvProd] productions) {
    if({s:convProd(_, [regexp(lRegex)], _), r:convProd(_, [regexp(rRegex), symb(lSym, [])], _)} := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex)) {

        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;
        
        Regex newRegex;
        if(just(<lastRegex, lastTags>) := getScopelessRegex(lRegex), 
            lastTags == tags,
            equals(repeatRegex, lastRegex)) 
            newRegex = withTags(\multi-iteration(repeatRegex));
        else             
            newRegex = concatenation(
                            alternation(
                                withTags(\multi-iteration(repeatRegex)),
                                empty()
                            ),
                            lRegex
                        );

        return createNewProd(sym, newRegex, {s, r});
    }
    return nothing();
}

@doc {
    Tries to apply the right repeat rule: 
    ```
    A -> (<s> X!)  A!
    A ->
    A -/> 
    ```
    => {Repetition-left}
    ```
    A -> (<s> X*)
    ```
}
Maybe[set[ConvProd]] repeatRightRegexes(Symbol sym, set[ConvProd] productions) {
    if({s:convProd(_, [], _), r:convProd(_, [regexp(rRegex), symb(lSym, [])], _)} := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex)) {

        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;

        return createNewProd(sym, withTags(alternation(
                            \multi-iteration(repeatRegex),
                            empty()
                        )), {s, r});
    }
    return nothing();
}

// Helpers
Maybe[set[ConvProd]] createNewProd(Symbol sym, Regex regex, set[ConvProd] sources) {
    <cachedExp, _, _> = cachedRegexToPSNFAandContainsScopes(regex);
    ConvProd prod = convProd(sym, [regexp(cachedExp)], {convProdSource(source) | source <- sources});
    return just({prod});
}

Maybe[Regex, Tags] getScopelessRegex(Regex regex) {
    hasScopes = containsScopes(regex);
    if(!hasScopes) return just(<regex, {}>);

    while(cached(inner, _, _) := regex) regex = inner;

    if(mark(tags, r) := regex) {
        hasScopes = containsScopes(r);
        if(!hasScopes)  return just(<r, tags>);
    }

    return nothing();
}
Symbol getWithoutLabel(label(_, sym)) = sym;
default Symbol getWithoutLabel(Symbol sym) = sym;

/*
    TODO: Also consider cases with modifiers, since I think this should also work. Would have to do better analysis on the regex's language though. E.g.
    ```
    A -> (<s> X!) A! >> Z
    A -> Y
    A -/> 
    ```
    => {Repetition-modifier-right}
    ```
    A -> (<s> X!)? (<s> (X! > Z)*) (Y > Z)
    ```
*/