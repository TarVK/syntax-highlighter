module search::ApplicableSuffixSearch

import Grammar;
import ParseTree;
import List;
import Set;
import IO;
import lang::rascal::format::Grammar;

import transformations::util::GetBaseDependency;
import search::util::GetDisjointCharClasses;

data PartialProduction = pp(Production prod, int index);
alias Stack = list[PartialProduction];
data SuffixesGroup = suffixGroup(set[Stack] suffixes, list[CharClass] history); // The history is a fixed (max) length prefix of how this group was reached (later used for follow restrictions and such)
alias Groups = set[SuffixesGroup];

TextGroups getSuffixes(grammar(startr, rules)) {
    Groups curGroups = {suffixGroup({[pp(p, 0)] | s <- startr, /p:prod(s, _, _) <- rules[s]}, [])};
    Groups allGroups = curGroups;

    historyLength = 1;

    changed = true;
    maxCycles = 25;
    while(changed) {
        changed = false;

        Groups newCurGroups = {};
        for(suffixGroup(suffixes, history) <- curGroups) {
            set[CharClass] nextClasses = {
                cls | [*_, pp(prod(_, parts, _), index)] <- suffixes,
                    \char-class(cls) := parts[index]
            };

            set[CharClassRegion] disjointClasses = getDisjointCharClasses(nextClasses);
            for(ccr(cc, overlapping) <- disjointClasses) {
                matchingSuffixes = {suffix | 
                    suffix:[*_, pp(prod(_, parts, _), index)] <- suffixes,
                    \char-class(cls) := parts[index],
                    cls in overlapping};
                
                newHistory = [*(size(history) == historyLength ? drop(1, history) : history), cc];
                set[Stack] newSuffixes = {*findNextCharacters(suffix, rules) | suffix <- matchingSuffixes};
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

    return simplify(allGroups);
}

// Expands the given stack into all possible next stacks, such that there's a character class at the top index
set[Stack] findNextCharacters(Stack suffix, map[Symbol sort, Production def] rules) {
    if([*base, pp(p:prod(_, parts, _), index)] := suffix) {
        nextIndex = index + 1;
        if(nextIndex >= size(parts)) {
            return findNextCharacters(base, rules);
        } else if(\char-class(_) := parts[nextIndex]) {
            return {[*base, pp(p, nextIndex)]};
        } else {
            // Critical step to remove data that does not contribute to suffix
            newBase = removeFinished([*base, pp(p, nextIndex)]);

            // Add all possible productions for the topmost symbol
            symbol = parts[nextIndex];
            set[Stack] out = {};
            for(/pn:prod(symb, newParts, _) <- rules[symbol]) {
                if(size(newParts) > 0 && getBaseDependency(newParts[0]) == getBaseDependency(symb)) continue; // Prevent infinite recursion (could happen with tau loops: syntax A = A | ...)
                out += findNextCharacters([*newBase, pp(pn, -1)], rules);
            }
            return out;
        }
    } else 
        return {};
}

Stack removeFinished(Stack stack) {
    if(size(stack) == 0) return stack;

    completed = (getBaseDependency(stack[0].prod.def): -1);
    for(i <- [0..size(stack)]){
        if(pp(prod(_, parts, _), index) := stack[i]) {
            if(index != size(parts)-1) completed = ();
            cur = parts[index];
            if(cur in completed) 
                return removeFinished(removeAll(stack, completed[cur]+1, i+1));

            completed[cur] = i;
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


// Helps with readability
alias Suffix = list[Symbol];
alias Suffixes = set[Suffix];
Suffix flatten(Stack suffix) {
    out = [];
    first = true;
    for(pp(prod(_, parts, _), startI) <- reverse(suffix)) {
        rEndI = size(parts);
        rStartI = startI + (first ? 0 : 1);
        if(rStartI < rEndI)
            for(i <- [rStartI..rEndI])
                out += parts[i];
        first = false;
    }
    return out;
}

data TextSuffixesGroup = textSuffixGroup(list[str] history, Suffixes suffixes); 
alias TextGroups = set[TextSuffixesGroup];

TextSuffixesGroup simplify(suffixGroup(suffixes, history)) 
    = textSuffixGroup([cc2rascal(cc) | cc <- history], {flatten(suffix) | suffix <- suffixes});
TextGroups simplify(Groups groups) = {simplify(group) | group <- groups};
// data TextSuffixesGroup = textSuffixGroup(list[str] history, set[Stack] suffixes); 
// alias TextGroups = set[TextSuffixesGroup];

// TextSuffixesGroup simplify(suffixGroup(suffixes, history)) 
//     = textSuffixGroup([cc2rascal(cc) | cc <- history], suffixes);
// TextGroups simplify(Groups groups) = {simplify(group) | group <- groups};