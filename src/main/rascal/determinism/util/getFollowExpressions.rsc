module determinism::util::getFollowExpressions

import ParseTree;
import Relation;
import Map;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::meta::LabelTools;
import regex::NFA;
import regex::Regex;
import regex::PSNFA;
import regex::regexToPSNFA;
import regex::RegexTransformations;
import regex::util::charClass;
import regex::PSNFATools;
import regex::RegexCache;
import regex::RegexProperties;

import testing::util::visualizeGrammars;
import conversion::conversionGrammar::fromConversionGrammar;

@doc {
    Given a grammar, for every non-terminal `A` in the grammar, retrieves a set `S` of regular expressions (indexed by their NFAs), such that:
    - ∀ X ∈ S . ∃ a,b ∈ symbol* . ∃ a derivation Start =>* a A X b 
        There may be symbols between `A` and `X`, but these will always match an empty string, possibly with extra lookaround conditions. Hence the follow expressions might be slightly less strict than the actual grammar
    - ∀ derivations Start =>* a A X b . ∃ X ∈ S 
        Again, possibly ignoring some lookarounds
    - !stopOnNewline => ∀ X ∈ S . (L(X) ∩ ({(p, $e, s) | p,s ∈ Σ*} \ EOF)) = ∅

    I.e. it retrieves all regular expressions that at some point can be to the right of `A` in a derivation. 
    
    If stopOnNewline is set to true, no new-line will only appear as the last character of any regular expression. 
}
IndexedRegexesMap getFollowExpressions(ConversionGrammar grammar)
    = getFollowExpressions(grammar, true);
IndexedRegexesMap getFollowExpressions(ConversionGrammar grammar, bool stopOnNewline) 
    = getFollowExpressions(grammar, getFirstExpressions(grammar, stopOnNewline), EOF, stopOnNewline);
IndexedRegexesMap getFollowExpressions(
    ConversionGrammar grammar, 
    IndexedRegexesMap firstExpressions, 
    Regex eof,
    bool stopOnNewline
) {
    // Define the output object, and a function to insert into it
    IndexedRegexesMap followExpressions = ();
    void addFollow(Symbol sym, Regex regex) {
        if(sym notin followExpressions)
            followExpressions[sym] = ();

        nfa = regexToPSNFA(regex);
        if(nfa notin followExpressions[sym])
            followExpressions[sym][nfa] = regex;
    }
    addFollow(grammar.\start, eof);

    // Analyze the direct follow expressions, and setup the parent following
    rel[Symbol, Symbol] parentFollow = {};    
    for(
        <def, p:convProd(_, parts)> <- grammar.productions, 
        [*_, ref(sym, _, _), *rest] := parts
    ) {
        symFirstExpressions = getFirstExpressions(rest, firstExpressions, stopOnNewline);
        
        nonEmptyOptions = {n | n <- symFirstExpressions, !acceptsEmpty(n)};
        followAcceptsEmpty = nonEmptyOptions != symFirstExpressions<0>;
        if(followAcceptsEmpty && sym != def) 
            parentFollow += {<sym, def>};

        for(n <- nonEmptyOptions)
            addFollow(sym, symFirstExpressions[n]);
        // addFollow(sym, getCachedRegex(
        //     reduceAlternation(alternation(
        //         [symFirstExpressions[n] | n <-nonEmptyOptions]
        //     ))
        // ));
    }

    // Perform the parent following and add their outputs
    parentFollow = parentFollow+; // transitive closure
    for(
        <sym, copySym> <- parentFollow, 
        copySym in followExpressions,
        exp <- followExpressions[copySym]<1>
    ) 
        addFollow(sym, exp);

        
    return followExpressions;
}

public Regex EOF = getCachedRegex(\negative-lookahead(empty(), character(anyCharClass())));
// public Regex EOF = getCachedRegex(character(anyCharClass()));

alias IndexedRegexesMap = map[Symbol, IndexedRegexes];
alias IndexedRegexes = map[NFA[State], Regex];

@doc {
    Retrieves possible first regular expressions, including empty if an empty sequence can be obtained
}
IndexedRegexesMap getFirstExpressions(ConversionGrammar grammar, bool stopOnNewline) {
    IndexedRegexesMap firstExpressions = (sym: () | sym <- grammar.productions<0>);

    solve(firstExpressions) {
        for(<sym, convProd(_, parts)> <- grammar.productions) {
            firstExpressions[sym] += getFirstExpressions(parts, firstExpressions, stopOnNewline);
        }
    }

    return firstExpressions;
}

@doc {
    Retrieves possible first regular expressions, including empty if an empty sequence can be obtained
}
IndexedRegexes getFirstExpressions(
    list[ConvSymbol] parts, 
    IndexedRegexesMap firstExpressions, 
    bool stopOnNewline
) {
    if([first, *rest] := parts) {
        IndexedRegexes newFirstRegexes = ();
        Regex emptyFollowPrefix = never();
        if(regexp(regex) := first) {
            if(!acceptsEmpty(regex)) newFirstRegexes = (regexToPSNFA(regex): regex);
            else {
                <rNonEmpty, rEmpty, rEmptyRestr> = factorOutEmpty(regex); 
                if(rNonEmpty != never()) newFirstRegexes = (regexToPSNFA(rNonEmpty): rNonEmpty);

                if(rEmpty != never())    emptyFollowPrefix = rEmpty;
                else                     emptyFollowPrefix = rEmptyRestr;
            }           
        } else if(ref(s, _, _) := first) {
            s = getWithoutLabel(s);
            firsts = s in firstExpressions ? firstExpressions[s] : ();

            emptyNFAoptions = {n | n <- firsts, acceptsEmpty(n)};
            if(emptyNFAoptions == {}) newFirstRegexes = firsts;
            else {
                newFirstRegexes = (n: firsts[n] | n <- firsts, n notin emptyNFAoptions);
                if(regexToPSNFA(emptyRegex) in emptyNFAoptions) 
                    emptyFollowPrefix = empty();
                else 
                    emptyFollowPrefix = getCachedRegex(reduceAlternation(alternation([
                        firsts[n] 
                        | n <- emptyNFAoptions
                    ])));
            }
        }

        // If the follow prefix is never, it means nothing can follow it
        if(emptyFollowPrefix==never()) return newFirstRegexes;

        // TODO: remove these no-newline checks. The regular expressions are used only as lookaheads, extra filters. So if non of the original regular expressions check for characters after a newline, neither does the concatenation (since the prefix of the concatenation does not consume any characters).
        // Otherwise we look at the remaining symbols and add it to the new first expressions
        originalEmptyFollowPrefix = emptyFollowPrefix;
        if(
            stopOnNewline,
            containsNewline(emptyFollowPrefix)
        ) {
            // Dropping the constraint means the language of our regex may contain some entries that aren't part of our input sequence
            emptyFollowPrefix = empty();
        }

        followExpressions = getFirstExpressions(rest, firstExpressions, stopOnNewline);
        // Prefix all follow expressions with the empty (with lookarounds) prefix
        if(emptyFollowPrefix != empty()) {
            IndexedRegexes combinedFollowExpressions = ();
            for(followNFA <- followExpressions) {
                followRegex = followExpressions[followNFA];
                combinedFollowRegex = simplifiedConcatenation(emptyFollowPrefix, followRegex);
                combinedFollowNFA = regexToPSNFA(combinedFollowRegex);
                
                // Save the simpler regex in the output, to prevent infinite unproductive loops
                combinedFollowExpressions[combinedFollowNFA] = combinedFollowNFA == followNFA
                    ? followRegex
                    : combinedFollowRegex;
            }
            followExpressions = combinedFollowExpressions;

        // A special case to allow for empty lookaheads at the end of a sequence, to support EOF regexes
        } else if(originalEmptyFollowPrefix != empty() && regexToPSNFA(emptyRegex) in followExpressions) {
            followExpressions = delete(followExpressions, regexToPSNFA(emptyRegex));
            followExpressions[regexToPSNFA(originalEmptyFollowPrefix)]
                = originalEmptyFollowPrefix;
        }


        for(nfa <- followExpressions, nfa notin newFirstRegexes)
            newFirstRegexes[nfa] = followExpressions[nfa];

        return newFirstRegexes;
    } else {
        return (regexToPSNFA(emptyRegex): emptyRegex);
    }
}

Regex emptyRegex = getCachedRegex(empty());