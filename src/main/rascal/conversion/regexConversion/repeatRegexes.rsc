module conversion::regexConversion::repeatRegexes

import Set;
import util::Maybe;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import conversion::regexConversion::liftScopes;
import regex::Regex;
import regex::RegexProperties;
import regex::Tags;
import regex::PSNFATools;
import regex::RegexCache;
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
    if({
            s:convProd(_, [regexp(fRegex)]), 
            r:convProd(_, [ref(lSym, [], sources), regexp(rRegex)]) // TODO: figure out whether sources should be forwarded in some way
        } := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex),
        !containsNewline(fRegex),
        !containsNewline(rRegex)
    ) {
        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;
        
        Regex newRegex;
        if(just(<firstRegex, firstTags>) := getScopelessRegex(fRegex), 
            firstTags == tags,
            equals(repeatRegex, firstRegex)
        ) 
            newRegex = withTags(\multi-iteration(repeatRegex));
        else             
            newRegex = liftScopes(concatenation(
                            fRegex, 
                            withTags(alternation(
                                \multi-iteration(repeatRegex),
                                empty()
                            ))
                        ));

        return createNewProd(sym, newRegex);
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
    if({
            s:convProd(_, []), 
            r:convProd(_, [ref(lSym, [], sources), regexp(rRegex)]) // TODO: figure out whether sources should be forwarded in some way
        } := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex),
        !containsNewline(rRegex)
    ) {
        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;

        return createNewProd(sym, withTags(alternation(
                    \multi-iteration(repeatRegex),
                    empty()
                )));
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
    if({
            s:convProd(_, [regexp(lRegex)]), 
            r:convProd(_, [regexp(rRegex), ref(lSym, [], sources)]) // TODO: figure out whether sources should be forwarded in some way
        } := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex),
        !containsNewline(rRegex) // Note, the l regex may contain newlines, since it becomes the end of the regex
    ) { 
        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;
        
        Regex newRegex;
        if(just(<lastRegex, lastTags>) := getScopelessRegex(lRegex), 
            lastTags == tags,
            equals(repeatRegex, lastRegex)
        ) 
            newRegex = withTags(\multi-iteration(repeatRegex));
        else             
            newRegex = liftScopes(concatenation(
                            withTags(alternation(
                                \multi-iteration(repeatRegex),
                                empty()
                            )),
                            lRegex
                        ));

        return createNewProd(sym, newRegex);
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
    if({
            s:convProd(_, []), 
            r:convProd(_, [regexp(rRegex), ref(lSym, [], sources)]) // TODO: figure out whether sources should be forwarded in some way
        } := productions,
        getWithoutLabel(lSym) == sym, 
        just(<repeatRegex, tags>) := getScopelessRegex(rRegex),
        !containsNewline(rRegex)
    ) {

        Regex withTags(Regex r) = size(tags)>0 ? mark(tags, r) : r;

        return createNewProd(sym, withTags(alternation(
                    \multi-iteration(repeatRegex),
                    empty()
                )));
    }
    return nothing();
}


@doc {
    Tries to apply the both repeat rule: 
    ```
    A -> (<s1> X!) A! 
    A -> Z
    A -> A! (<s2> Y!) 
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
    if({
            p:convProd(_, [regexp(pRegex), ref(pSym, [], pSources)]), // TODO: figure out whether sources should be forwarded in some way
            m:convProd(_, [regexp(mRegex)]), 
            s:convProd(_, [ref(sSym, [], sSources), regexp(sRegex)]) // TODO: figure out whether sources should be forwarded in some way
        } := productions,
        getWithoutLabel(pSym) == sym, 
        getWithoutLabel(sSym) == sym, 
        just(<prefixRegex, prefixTags>) := getScopelessRegex(pRegex),
        just(<suffixRegex, suffixTags>) := getScopelessRegex(sRegex),
        !containsNewline(pRegex),
        !containsNewline(mRegex),
        !containsNewline(sRegex)
    ) {
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
        
        return createNewProd(sym, newRegex);
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
    if({
            p:convProd(_, [regexp(pRegex), ref(pSym, [], pSources)]), // TODO: figure out whether sources should be forwarded in some way
            m:convProd(_, []), 
            s:convProd(_, [ref(sSym, [], sSources), regexp(sRegex)]) // TODO: figure out whether sources should be forwarded in some way
        } := productions,
        getWithoutLabel(pSym) == sym, 
        getWithoutLabel(sSym) == sym, 
        just(<prefixRegex, prefixTags>) := getScopelessRegex(pRegex),
        just(<suffixRegex, suffixTags>) := getScopelessRegex(sRegex),
        !containsNewline(pRegex),
        !containsNewline(sRegex)
    ) {
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

        return createNewProd(sym, newRegex);
    }
    return nothing();
}

// Helpers
Maybe[set[ConvProd]] createNewProd(Symbol sym, Regex regex) {
    cachedExp = getCachedRegex(regex);
    ConvProd prod = convProd(sym, [regexp(cachedExp)]);
    return just({prod});
}

Maybe[tuple[Regex, Tags]] getScopelessRegex(Regex regex) {
    hasScopes = containsScopes(regex);
    if(!hasScopes) return just(<regex, {}>);

    Maybe[tuple[Regex, Tags]] getScopelessRegexRec(Regex regex) {
        switch(regex){
            case mark(tags, r): {        
                hasScopes = containsScopes(r);
                if(!hasScopes) return just(<r, tags>);
                return nothing();
            }
            case meta(r, m): {
                if(just(<newR, tags>) := getScopelessRegexRec(r)) 
                    return just(<meta(newR, m), tags>);
                return nothing();
            }
            default: return nothing();
        }
    }
    return getScopelessRegexRec(regex);
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