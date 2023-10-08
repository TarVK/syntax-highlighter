module search::SuffixGroups

import Grammar;
import ParseTree;
import List;
import Set;
import IO;
import lang::rascal::format::Grammar;

import transformations::util::GetBaseDependency;
import search::util::GetDisjointCharClasses;

data PartialProduction = pp(Production prod, int index);
alias SuffixStack = list[PartialProduction];
data SuffixesGroup = suffixGroup(set[SuffixStack] suffixes, list[CharClass] history); // The history is a fixed (max) length prefix of how this group was reached (later used for follow restrictions and such)
alias Groups = set[SuffixesGroup];

Groups getSuffixGroups(grammar(startr, rules)) {
    Groups curGroups = {suffixGroup({[pp(p, 0)] | s <- startr, /p:prod(s, _, _) <- rules[s]}, [])};
    Groups allGroups = curGroups;

    historyLength = 1;

    changed = true;
    maxCycles = 5;
    while(changed) {
        changed = false;

        Groups newCurGroups = {};
        for(suffixGroup(suffixes, history) <- curGroups) {
            set[CharClass] nextClasses = {getCurrentCharacter(stack) | stack <- suffixes};

            set[CharClassRegion] disjointClasses = getDisjointCharClasses(nextClasses);
            for(ccr(cc, overlapping) <- disjointClasses) {
                matchingSuffixes = {suffix | 
                    suffix:[*_, pp(prod(_, parts, _), index)] <- suffixes,
                    \char-class(cls) := parts[index],
                    cls in overlapping};
                
                newHistory = [*(size(history) == historyLength ? drop(1, history) : history), cc];
                set[SuffixStack] newSuffixes = {*findNextCharacters(suffix, rules) | suffix <- matchingSuffixes};
                newGroup = suffixGroup(newSuffixes, newHistory);

                if(!(newGroup in allGroups)) {
                    changed = true;
                    allGroups += newGroup;
                    newCurGroups += newGroup;
                }
            }
        }

        curGroups = newCurGroups;
        
        maxCycles -= 1;
        if(maxCycles<=0) break;
    }

    return allGroups;
}

data LoopException = loopException(Production rule);

CharClass getCurrentCharacter(SuffixStack stack) {
    if([*_, pp(prod(_, parts, _), index)] := stack && \char-class(cls) := parts[index]){
        return cls;
    }              
    return [];
}

// Expands the given stack into all possible next stacks, such that there's a character class at the top index
set[SuffixStack] findNextCharacters(SuffixStack suffix, map[Symbol sort, Production def] rules, set[Symbol] encountered = {}) {
    if([*base, pp(p:prod(_, parts, _), index)] := suffix) {
        nextIndex = index + 1;
        if(nextIndex >= size(parts)) {
            return findNextCharacters(base, rules);
        } else if(\char-class(_) := parts[nextIndex]) {
            return {[*base, pp(p, nextIndex)]};
        } else {
            symbol = getBaseDependency(parts[nextIndex]);
            encountered += symbol; 

            // Critical step to remove data that does not contribute to suffix
            newBase = removeFinished([*base, pp(p, nextIndex)]);

            // Add all possible productions for the topmost symbol
            set[SuffixStack] out = {};
            for(/pn:prod(_, newParts, _) <- rules[symbol]) {
                // Prevent infinite recursion
                if(size(newParts) > 0 && getBaseDependency(newParts[0]) in encountered) {
                    if(size(newParts) > 1) throw loopException(pn); // Loop adds suffix, which isn't allowed
                    continue; //  (could happen with tau loops: syntax A = A | ...)
                }

                out += findNextCharacters([*newBase, pp(pn, -1)], rules);
            }
            return out;
        }
    } else 
        return {};
}

SuffixStack removeFinished(SuffixStack stack) {
    if(size(stack) == 0) return stack;

    map[Symbol, int] completed = ();
    for(i <- [0..size(stack)]){
        if(pp(prod(symb, parts, _), index) := stack[i]) {
            completed[symb] = i;
            if(index != size(parts)-1) completed = ();
            // else if(i==0 && size(parts)!=1) return removeFinished(tail(stack)); // If there is only 1 part, it's a unit rule and hence these suffixes add info for what can be matched

            cur = parts[index];
            if(cur in completed) 
                return removeFinished(removeAll(stack, completed[cur], i+1));
        }
    }

    return stack;
}

list[&T] removeAll(list[&T] l, int from, from) = l;
list[&T] removeAll([], int from, int to) = [];
list[&T] removeAll(l:[&T f, *&T rest], int from, int to) = to <= 0 
    ? l 
    : from <= 0
        ? removeAll(rest, from-1, to-1)
        : f + removeAll(rest, from-1, to-1);