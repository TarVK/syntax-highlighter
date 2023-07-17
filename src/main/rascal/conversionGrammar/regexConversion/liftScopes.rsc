module conversionGrammar::regexConversion::liftScopes

import Set;
import List;
import IO;

import Scope;
import conversionGrammar::RegexCache;
import regex::Tags;
import regex::Regex;
import regex::PSNFA;
import regex::PSNFACombinators;

// TODO: also merge nested mark constructors

@doc {
    Tries to apply scope lifting if possible:
    ```
    A -> (<s> X)(<s> Y)
    B -> (<s> X)|(<s> Y)
    ```
    => {Scope lifting}
    ```
    A -> (<s> XY)
    B -> (<s> X|Y)
    ```

    This is done exhaustively. This rule is not based on exact grammar structure, instead teh PSNFA is analyzed to decide whether internal scopes can be moved upwards. 
}
Regex liftScopes(Regex regex) {
    <cachedRegex, psnfa, hasScope> = cachedRegexToPSNFAandContainsScopes(regex);
    
    liftableScopes = findLiftableScopes(cachedRegex);
    if(size(liftableScopes)>0) {
        Tags removeScopes(Tags tags) = tags - {t | t:scopeTag(scopes) <- tags, [*scopes, *_] := liftableScopes};

        regexWithoutScope = visit(cachedRegex) {
            case mark(tags, exp): {
                remainingTags = removeScopes(tags);
                insert size(remainingTags)>0 ? mark(remainingTags, exp) : exp;
            }
        };

        if(cached(nonCached, _, _) := regexWithoutScope) 
            return cached(mark({scopeTag(liftableScopes)}, nonCached), psnfa, true);
    }

    return cachedRegex;
}

list[Scope] findLiftableScopes(Regex regex) {
    <cachedRegex, psnfa, hasScope> = cachedRegexToPSNFAandContainsScopes(regex);
    <prefixStates, mainStates, suffixStates> = getPSNFApartition(psnfa);
    contextStates = prefixStates + suffixStates;

    // Extract every combination of scopes
    set[set[Scopes]] getScopeSets(set[State] inStates) = 
        {{scopes | scopeTag(scopes) <- tags} 
            | <from, character(_, tagsClass), _> <- psnfa.transitions, 
            from in inStates, 
            tags <- tagsClass};


    contextScopesSets = getScopeSets(contextStates);
    mainScopesSets = getScopeSets(mainStates);

    set[Scope] mainScopes = {*scopes | scopesSet <- mainScopesSets, scopes <- scopesSet};

    // Find all scopes that are present in all main transitions
    universalScopes = {scope | scope <- mainScopes, 
        all(scopesSet <- mainScopesSets, any(scopes <- scopesSet, scope in scopes))};

    // Find all universal scopes that are not part of the context matches
    universalNonContextScopes = {scope | scope <- universalScopes,
        !any(scopesSet <- contextScopesSets, scopes <- scopesSet, scope in scopes)};


    list[Scope] liftableScopes = [];
    foundAllScopes = false;
    while(!foundAllScopes) {
        foundAllScopes = true;
        for(scope <- universalNonContextScopes) {
            // Check whether this is the first most/outermost scope (apart from the already found liftableScopes)
            isAlwaysNext = all(scopesSet <- mainScopesSets, 
                any(scopes <- scopesSet, startPrefix([*liftableScopes, scope], scopes)));
            if(!isAlwaysNext) continue;

            foundAllScopes = false;
            liftableScopes += [scope];
            break;
        }
    }

    return liftableScopes;
}

bool startPrefix(list[&T] prefix, list[&T] target) {
    if(size(target)<size(prefix)) return false;
    for(i <- [0..size(prefix)]) {
        if(prefix[i] != target[i]) return false;
    }
    return true;
}