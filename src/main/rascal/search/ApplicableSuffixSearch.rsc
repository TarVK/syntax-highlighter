module search::ApplicableSuffixSearch

import Grammar;
import ParseTree;

import search::util::GetDisjointCharClasses;

data PartialProduction = pp(Production prod, int index);
alias Stack = list[PartialProduction];
data SuffixesGroup = suffixGroup(set[Stack] suffixes, list[CharClass] history); // The history is a fixed (max) length prefix of how this group was reached (later used for follow restrictions and such)
alias Groups = set[SuffixesGroup];

int getSuffixes(grammar(startr, rules)) {
    Groups curGroups = {suffixGroup({[pp(p, 0) | s <- startr, p:prod(s, _, _) <- \rules[s]]}, [])};
    Groups allGroups = curGroups;

    changed = true;
    while(changed) {
        changed = false;

        for(suffixGroup(suffixes, history) <- curGroups) {
            set[CharClass] nextClasses = {
                cls | [*_, pp(prod(_, parts, _), index)] <- suffixes,
                    \char-class(cls) := parts[index]
            };

            set[CharClass] disjointClasses = getDisjointCharClasses(nextClasses);
            for(cc <- disjointClasses) {
                matchingSuffixes = {suffix | 
                    suffix:[*_, pp(prod(_, parts, _), index)] <- suffixes,
                    \char-class(cls) := parts[index],
                    overlaps(cc, cls)};
                
            }
        }
    }

    return 3;
}

// Helps with readability
alias Suffix = list[Symbol];
alias Suffixes = list[Suffix];
Suffix flatten(Stack suffix) {
    out = [];
    for(pp(prod(_, parts, _), starti) <- suffix) {
        for(i <- [starti, size(parts)]) {
            out += parts[i];
        }
    }
    return out;
}