module conversion::regexConversion::RegexConversion

import Set;
import Map;
import List;
import util::Maybe;
import Relation;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::unionRegexes;
import conversion::regexConversion::concatenateRegexes;
import conversion::regexConversion::substituteRegexes;
import conversion::regexConversion::lowerModifiers;
import conversion::regexConversion::repeatRegexes;
import conversion::regexConversion::checkModifiers;
import regex::RegexToPSNFA;
import regex::Regex;
import regex::PSNFATools;
import Warning;


@doc {
    Combines productions into regular expressions in the given grammar
}
WithWarnings[ConversionGrammar] convertToRegularExpressions(ConversionGrammar grammar) {
    rel[Symbol, ConvProd] loweredModifierProductions = {
        <def, lowerModifiers(prod)> 
        | <def, prod> <- grammar.productions};

    productions = Relation::index(loweredModifierProductions);
    Symbol \start = grammar.\start;

    bool changed = true;
    bool first = true;
    ProdMap tentativeProductions = productions;
    while(changed) {
        <changed, tentativeProductions> = applyRegexRules(\start, tentativeProductions);

        // If no more pure regex rules apply, try sequence substitution which could kick-off new regex rules
        // We don't perform sequence substituion right away, since it may unneccessarily increase the amount of work by duplicating symbols
        if(changed || first) {
            productions = tentativeProductions; // Only update productions if regex changes were made
            for(sym <- productions<0>, sym != grammar.\start) {
                <_, merged, tentativeProductions> = substituteSequence(tentativeProductions, sym);
                if(merged) productions = tentativeProductions;
            }
            changed = true;
        }

        first = false;
    }

    outGrammar = convGrammar(\start, toRel(productions));
    return checkModifiers(outGrammar);
}

@doc {
    Applies the pure regex transformation rules:
    - Union
    - Concatenation
    - Substitution
    - Scope lifting
    - Modifier lowering

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
            count = Set::size(symProductions);
            if(count > 1) {
                combined = unionRegexes(symProductions);
                if(size(combined) < count) {
                    productions[sym] = combined;
                    newDirty += sym;
                }
            }

            // Try to apply the substitution rule
            if(sym != \start) {
                <affected, productions> = substituteRegexes(productions, sym);
                newDirty += affected;
            }

            // Try to apply the repeat rule
            if(just(repeatRegexRule) := repeatRegexes(sym, symProductions)) {
                productions[sym] = repeatRegexRule;
                newDirty += sym;
            }
        }

        if(size(newDirty)>0) changed = true;
        dirty = newDirty;
    }

    return <changed, productions>;
}