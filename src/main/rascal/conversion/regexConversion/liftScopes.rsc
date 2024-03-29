module conversion::regexConversion::liftScopes

import Set;
import List;
import IO;

import Scope;
import regex::Tags;
import regex::Regex;
import regex::RegexCache;
import regex::PSNFA;
import regex::PSNFACombinators;
import regex::RegexStripping;

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

    This is done exhaustively. This rule is not based on exact grammar structure, instead the PSNFA is analyzed to decide whether internal scopes can be moved upwards. 
}
Regex liftScopes(Regex regex) {
    <cachedRegex, psnfa, <hasScope, _>> = cachedRegexToPSNFAandFlags(regex);
    
    liftableScopesSet = findLiftableScopes(cachedRegex);
    if(size(liftableScopesSet)>0) {
        cachedRegex = removeInnerRegexCache(cachedRegex);
        Tags removeScopes(Tags tags) = tags - {t | t:scopeTag(scopes) <- tags, 
            scopeList := toList(scopes),
            // Remove scopes tags that is a prefix of lifable scopes, e.g. `liftableScope = [a, b]`, `scopes = [a]`
            any(liftableScopes <- liftableScopesSet, [*scopeList, *_] := liftableScopes)}; 

        regexWithoutScope = visit(cachedRegex) {
            case mark(tags, exp): {
                remainingTags = removeScopes(tags);
                insert size(remainingTags)>0 ? mark(remainingTags, exp) : exp;
            }
        };

        if(meta(nonCached, cacheMeta(_, <_, nl>)) := regexWithoutScope) 
            return meta(
                mark(
                    {scopeTag(toScopes(liftableScopes)) | liftableScopes <- liftableScopesSet}, 
                    nonCached
                ),
                cacheMeta(
                    psnfa,
                    <true, nl>
                )
            );
    }

    return cachedRegex;
}

set[list[Scope]] findLiftableScopes(Regex regex) {
    <mainScopesSets, universalNonContextScopes> = findUniversalMainScopes(regex);

    set[list[Scope]] liftableScopesSet = {};

    for(outerScope <- universalNonContextScopes) {
        list[Scope] liftableScopes = [outerScope];

        // Check whether this is a first most/outermost scope
        isAlwaysNext = size(mainScopesSets)==0  // Explicit check to deal with Rascal `all` bug on empty domains
            || all(scopesSet <- mainScopesSets, 
                any(scopes <- scopesSet, startPrefix([outerScope], scopes)));
        if(!isAlwaysNext) continue;
        
        // Try to augment it with sub-scopes
        foundAllScopes = false;
        while(!foundAllScopes) {
            foundAllScopes = true;
            for(scope <- universalNonContextScopes) {
                // Check whether this is a first most/outermost scope (apart from the already found liftableScopes)
                isAlwaysNext = size(mainScopesSets)==0
                    || all(scopesSet <- mainScopesSets, 
                    any(scopes <- scopesSet, startPrefix([*liftableScopes, scope], scopes)));
                if(!isAlwaysNext) continue;

                foundAllScopes = false;
                liftableScopes += [scope];
                break;
            }
        }

        // Add to output
        liftableScopesSet += liftableScopes;
    }

    return liftableScopesSet;
}

@doc {
    Retrieves all the main scope sets, as well as a set of all scopes that only occur in all transitions of the main match of the regex and not the context match.
}
tuple[set[set[ScopeList]], set[Scope]] findUniversalMainScopes(Regex regex) {
    <cachedRegex, psnfa, <hasScope, _>> = cachedRegexToPSNFAandFlags(regex);
    <prefixStates, mainStates, suffixStates> = getPSNFApartition(psnfa);
    contextStates = prefixStates + suffixStates;

    // Extract every combination of scopes
    set[set[ScopeList]] getScopeSets(set[State] inStates) = 
        {{toList(scopes) | scopeTag(scopes) <- tags} 
            | <from, character(_, tagsClass), _> <- psnfa.transitions, 
            from in inStates, 
            tags <- tagsClass};


    contextScopesSets = getScopeSets(contextStates);
    mainScopesSets = getScopeSets(mainStates);

    set[Scope] mainScopes = {*scopes | scopesSet <- mainScopesSets, scopes <- scopesSet};

    // Find all scopes that are present in all main transitions
    universalScopes = {scope | scope <- mainScopes, 
        all(scopesSet <- mainScopesSets, any(scopes <- scopesSet, scope in scopes))};

    // Find all universal scopes that are not part of the context (prefix/suffix) matches
    universalNonContextScopes = {scope | scope <- universalScopes,
        !any(scopesSet <- contextScopesSets, scopes <- scopesSet, scope in scopes)};

    return <mainScopesSets, universalNonContextScopes>;
}

bool startPrefix(list[&T] prefix, list[&T] target) {
    if(size(target)<size(prefix)) return false;
    for(i <- [0..size(prefix)]) {
        if(prefix[i] != target[i]) return false;
    }
    return true;
}