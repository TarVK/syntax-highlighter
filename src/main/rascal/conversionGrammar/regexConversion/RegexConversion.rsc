module conversionGrammar::regexConversion::RegexConversion

import Set;
import Map;
import List;
import Relation;
import IO;

import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::unionRegexes;
import conversionGrammar::regexConversion::concatenateRegexes;
import conversionGrammar::regexConversion::substituteRegexes;
import conversionGrammar::regexConversion::lowerModifiers;
import regex::RegexToPSNFA;
import regex::Regex;
import regex::PSNFATools;


@doc {
    Combines productions into regular expressions in the given grammar
}
ConversionGrammar convertToRegularExpressions(ConversionGrammar grammar) {
    rel[Symbol, ConvProd] loweredModifierProductions = {
        <def, lowerModifiers(prod)> 
        | <def, prod> <- grammar.productions};

    productions = Relation::index(loweredModifierProductions);
    Symbol \start = grammar.\start;

    bool changed = true;
    ProdMap tentativeProductions = productions;
    while(changed) {
        <changed, tentativeProductions> = applyRegexRules(\start, tentativeProductions);

        // If no more pure regex rules apply, try sequence substitution which could kick-off new regex rules
        // We don't perform sequence substituion right away, since it may unneccessarily increase the amount of work by duplicating symbols
        if(changed) {
            productions = tentativeProductions; // Only update productions, if regex changes were made
            for(sym <- productions<0>, sym != grammar.\start) 
                <_, tentativeProductions> = substituteSequence(tentativeProductions, sym);
        }
    }

    return convGrammar(\start, toRel(productions));
}

@doc {
    Applies the pure regex transformation rules:
    - Union
    - Concatenation
    - Substitution
    - Scope lifting

    Until no more rules can be applied
}
tuple[bool, ProdMap] applyRegexRules(Symbol \start, ProdMap productions) {
    set[Symbol] dirty = productions<0>;
    bool changed = false;

    while(size(dirty)>0){
        set[Symbol] newDirty = {};
        for(sym <- dirty) {
            if(sym notin productions) continue;

            // Try to apply the union rule
            symProductions = productions[sym];
            combined = unionRegexes(symProductions);
            if(size(combined) < size(symProductions)) {
                productions[sym] = combined;        
                newDirty += sym;
            }

            // Try to apply the substitution rule
            if(sym != \start) {
                <affected, productions> = substituteRegexes(productions, sym);
                newDirty += affected;
            }
        }

        if(size(newDirty)>0) changed = true;
        dirty = newDirty;
    }

    return <changed, productions>;
}