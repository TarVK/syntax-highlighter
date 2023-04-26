module search::ConflictSearch

import Grammar;
import ParseTree;
import List;
import Set;
import IO;
import lang::rascal::format::Grammar;

import search::SuffixGroups;
import search::RegularApplicableSuffixes;
import search::util::GetDisjointCharClasses;
import transformations::MohriNederhof;


data ConflictData = conflictData(Grammar approximation, map[Production, ProdConflictData] conflicts);
data ProdConflictData = prodConflict(Production approx, set[SuffixStack] conflicts);

ConflictData getConflictData(Grammar gr) {
    approximation = gr;
    suffixes = getRegularApplicableSuffixes(approximation);
    
    map[Production, ProdConflictData] conflicts = ();
    for(p:prod(_, _, {prodSource(def, parts, attr, 0)}) <- suffixes) {
        conflicts[prod(def, parts, attr)] = prodConflict(p, suffixes[p]);
    }

    return conflictData(approximation, conflicts);
}

set[list[Symbol]] getConflicts(Grammar approximation, prodConflict(prod, conflicts), int prefixLength, bool log) {
    compatible = filterCharacterCompatibilities(prod, conflicts, prefixLength, approximation, log);
    return {getSuffix(stack) | stack <- compatible};
}
