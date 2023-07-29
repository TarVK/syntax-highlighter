module conversion::regexConversion::repeatRegexes

import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::liftScopes;
import regex::Regex;
import regex::Tags;
import regex::PSNFATools;
import conversion::util::RegexCache;
import Scope;

@doc {
    Tries to apply any of the repeat rules and variations:
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
    and
    ```
    A -> (<s1> X!) A! 
    A -> A! (<s2> Y!) 
    A -> Z
    A -/> 
    ```
    => {Repetition-both}
    ```
    A -> (<s1> X*) Z (<s2> Y*)
    ```

    Internally applies the rules:
    - Scope lifting
}
Maybe[set[ConvProd]] repeatRegexes(Symbol sym, set[ConvProd] productions) {
    if(s:just(_) := repeatMultiLeftRegexes(sym, productions)) return s;
    if(s:just(_) := repeatLeftRegexes(sym, productions)) return s;
    if(s:just(_) := repeatMultiRightRegexes(sym, productions)) return s;
    if(s:just(_) := repeatRightRegexes(sym, productions)) return s;
    if(s:just(_) := repeatMultiBothRegexes(sym, productions)) return s;
    if(s:just(_) := repeatBothRegexes(sym, productions)) return s;

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

    Internally applies the rules:
    - Scope lifting
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
            newRegex = liftScopes(concatenation(
                            fRegex, 
                            withTags(alternation(
                                \multi-iteration(repeatRegex),
                                empty()
                            ))
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

    Internally applies the rules:
    - Scope lifting
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
            newRegex = liftScopes(concatenation(
                            withTags(alternation(
                                \multi-iteration(repeatRegex),
                                empty()
                            )),
                            lRegex
                        ));

        return createNewProd(sym, newRegex, {s, r});
    }
    return nothing();
}

@doc {
    Tries to apply the right repeat rule: 
    ```
    A -> (<s> X!) A!
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


@doc {
    Tries to apply the both repeat rule: 
    ```
    A -> (<s1> X!) A! 
    A -> A! (<s2> Y!) 
    A -> Z
    A -/> 
    ```
    => {Repetition-both}
    ```
    A -> (<s1> X*) Z (<s2> Y*)
    ```
    Where Z is non-empty
    
    Internally applies the rules:
    - Scope lifting
}
Maybe[set[ConvProd]] repeatMultiBothRegexes(Symbol sym, set[ConvProd] productions) {
    if({m:convProd(_, [regexp(mRegex)], _), 
        p:convProd(_, [regexp(pRegex), symb(pSym, [])], _),
        s:convProd(_, [symb(sSym, []), regexp(sRegex)], _)
    } := productions,
        getWithoutLabel(pSym) == sym, 
        getWithoutLabel(sSym) == sym, 
        just(<prefixRegex, prefixTags>) := getScopelessRegex(pRegex),
        just(<suffixRegex, suffixTags>) := getScopelessRegex(sRegex)) {

        Regex withTags(Tags tags, Regex r) = size(tags)>0 ? mark(tags, r) : r;
        
        Regex getDefault() = 
            liftScopes(concatenation(
                liftScopes(concatenation(
                    withTags(prefixTags, alternation(
                        \multi-iteration(prefixRegex),
                        empty()
                    )),
                    mRegex
                )), 
                withTags(suffixTags, alternation(
                    \multi-iteration(suffixRegex),
                    empty()
                ))
            ));
        
        Regex newRegex;
        if(just(<middleRegex, middleTags>) := getScopelessRegex(mRegex)) {
            if(equals(middleRegex, prefixRegex),  middleTags==prefixTags) {
                newRegex = liftScopes(concatenation(
                    withTags(prefixTags, \multi-iteration(prefixRegex)),
                    withTags(suffixTags, alternation(
                        \multi-iteration(suffixRegex),
                        empty()
                    ))
                ));
            } else if (equals(middleRegex, suffixRegex),  middleTags==suffixTags) {
                newRegex = liftScopes(concatenation(
                    withTags(prefixTags, alternation(
                        \multi-iteration(prefixRegex),
                        empty()
                    )),
                    withTags(suffixTags, \multi-iteration(suffixRegex))
                ));
            } else newRegex = getDefault();
        } else newRegex = getDefault();
        
        return createNewProd(sym, newRegex, {m, p, s});
    }
    return nothing();
}

@doc {
    Tries to apply the both repeat rule: 
    ```
    A -> (<s1> X!) A! 
    A -> A! (<s2> Y!) 
    A -> 
    A -/> 
    ```
    => {Repetition-both}
    ```
    A -> (<s1> X*) (<s2> Y*)
    ```
}
Maybe[set[ConvProd]] repeatBothRegexes(Symbol sym, set[ConvProd] productions) {
    if({m:convProd(_, [], _), 
        p:convProd(_, [regexp(pRegex), symb(pSym, [])], _),
        s:convProd(_, [symb(sSym, []), regexp(sRegex)], _)
    } := productions,
        getWithoutLabel(pSym) == sym, 
        getWithoutLabel(sSym) == sym, 
        just(<prefixRegex, prefixTags>) := getScopelessRegex(pRegex),
        just(<suffixRegex, suffixTags>) := getScopelessRegex(sRegex)) {

        Regex withTags(Tags tags, Regex r) = size(tags)>0 ? mark(tags, r) : r;

        Regex newRegex = liftScopes(concatenation(
            withTags(prefixTags, alternation(
                \multi-iteration(prefixRegex),
                empty()
            )),
            withTags(suffixTags, alternation(
                \multi-iteration(suffixRegex),
                empty()
            ))
        ));

        return createNewProd(sym, newRegex, {m, p, s});
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

/*
    TODO: Also consider cases with modifiers, since I think this should also work. Would have to do better analysis on the regex's language though. E.g.
    ```
    A -> (<s> X!) A! >> Z
    A -> Y
    A -/> 
    ```
    => {Repetition-modifier-right}
    ```
    A -> (<s> X)? (<s> (X > Z)*) (Y > Z)
    ```
*/