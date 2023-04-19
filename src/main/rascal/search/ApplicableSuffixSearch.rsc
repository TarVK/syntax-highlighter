module search::ApplicableSuffixSearch

import Grammar;
import ParseTree;
import List;
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

    historyLength = 5;

    changed = true;
    maxCycles = 10;
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

                set[Stack] newSuffixes = {};
                for(suffix <- matchingSuffixes) {
                    while([*base, pp(prod(_, parts, _), index)] := suffix, 
                            index+1 >= size(parts)) {
                        // Drop the top production, since it's finished
                        suffix = base;
                    }

                    if([*base, pp(p, index)] := suffix) {
                        suffix = [*base, pp(p, index+1)];
                        newSuffixes += findNextCharacters(suffix, rules);
                    }
                }

                newGroup = suffixGroup(newSuffixes, newHistory);
                newCurGroups += newGroup;

                if(!(newGroup in allGroups)) changed = true;
                allGroups += newGroup;
            }
        }

        curGroups = newCurGroups;
        
        maxCycles -= 1;
        if(maxCycles<=0) break;
    }

    return simplify(curGroups);
}

// Expands the given stack into all possible next stacks, such that there's a character class at the top index
set[Stack] findNextCharacters(Stack suffix, map[Symbol sort, Production def] rules) {
    if([*_, pp(prod(_, parts, _), index)] := suffix) {
        if(\char-class(_) := parts[index])
            return {suffix};
        else {
            // While the bottom most production is done (except for other rules on the stack) remove it
            while([pp(prod(_, bottomParts, _), bottomIndex), *_] := suffix 
                    && size(bottomParts)-1 == bottomIndex)
                suffix = drop(1, suffix);

            // Add all possible productions for the topmost symbol
            symbol = parts[index];
            set[Stack] out = {};
            for(/p:prod(symb, newParts, _) <- rules[symbol],
                    size(newParts) > 0) {
                if(getBaseDependency(newParts[0]) == getBaseDependency(symb)) continue; // Prevent infinite recursion (could happen with tau loops: syntax A = A | ...)
                out += findNextCharacters([*suffix, pp(p, 0)], rules);
            }
            return out;
        }
    } else return {};
}

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
            for(i <- [rStartI..rEndI]) {
                out += parts[i];
            }
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