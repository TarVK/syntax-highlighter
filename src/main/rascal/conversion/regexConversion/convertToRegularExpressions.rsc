module conversion::regexConversion::convertToRegularExpressions

import Set;
import Map;
import List;
import util::Maybe;
import Relation;
import IO;

import Logging;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::regexConversion::unionRegexes;
import conversion::regexConversion::concatenateRegexes;
import conversion::regexConversion::substituteRegexes;
import conversion::regexConversion::lowerModifiers;
import conversion::regexConversion::repeatRegexes;
import conversion::regexConversion::checkModifiers;
import regex::regexToPSNFA;
import regex::RegexCache;
import regex::Regex;
import regex::PSNFATools;
import Warning;


@doc {
    Combines productions into regular expressions in the given grammar

    The guarantee on the output grammar is:
        - The language is equivalent to that of the input grammar (unless warnings are generated, in which case it's possibly broader)
        - All modifiers have been removed from the grammar
}
WithWarnings[ConversionGrammar] convertToRegularExpressions(ConversionGrammar grammar, Logger log) {
    log(Section(), "to regular expressions");
    rel[Symbol, ConvProd] loweredModifierProductions = {
        <def, lowerModifiers(prod)> 
        | <def, prod> <- grammar.productions};

    productions = Relation::index(loweredModifierProductions);
    Symbol \start = grammar.\start;

    // Get rid of empty productions immediately
    for(sym <- productions<0>, {p:convProd(lDef, [])} := productions[sym], sym != grammar.\start) {
        productions[sym] = {convProd(lDef, [regexp(getCachedRegex(empty()))])};
        <_, productions> = substituteRegexes(productions, sym);
    }

    // Perform concatenation immediately whenever possible
    for(sym <- productions<0>)
        productions[sym] = concatenateRegexes(productions[sym]);

    void applyRegexConversions() {
        bool changed = true;
        bool first = true;
        ProdMap tentativeProductions = productions;
        while(changed) {
            <changed, tentativeProductions> = applyRegexRules(\start, tentativeProductions, log);
            log(Progress(), "applied rules exhaustively");

            // If no more pure regex rules apply, try sequence substitution which could kick-off new regex rules
            // We don't perform sequence substituion right away, since it may unneccessarily increase the amount of work by duplicating symbols
            if(changed || first) {
                productions = tentativeProductions; // Only update productions if regex changes were made
                bool newChanged = false;
                for(sym <- productions<0>, sym != grammar.\start) {
                    <_, merged, tentativeProductions> = substituteSequence(productions, sym);
                    if(merged) {
                        productions = tentativeProductions;
                        changed = true;
                        newChanged = true;
                    }
                }
                if(newChanged) log(Progress(), "improved by substitution");
            }

            first = false;
        }
    }
    applyRegexConversions();

    // Apply the rules once more, after getting rid of modifiers we can't apply
    outGrammar = convGrammar(\start, toRel(productions));
    <warnings, outGrammar> = checkModifiers(outGrammar);
    if(size(warnings)>0) {
        for(warning <- warnings) log(Warning(), warning);
        productions = Relation::index(outGrammar.productions);
        log(Progress(), "removed unresolved modifiers");
        applyRegexConversions();
        outGrammar = convGrammar(\start, toRel(productions));
    }
    
    return <warnings, outGrammar>;
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
tuple[bool, ProdMap] applyRegexRules(Symbol \start, ProdMap productions, Logger log) {
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
                    log(ProgressDetailed(), "unioned prods of symbol <sym>");
                }
            }

            // Try to apply the substitution rule
            if(sym != \start) {
                <affected, productions> = substituteRegexes(productions, sym);
                newDirty += affected;
                if(size(affected)>0) 
                    log(ProgressDetailed(), "substituted symbol <sym>");
            }

            // Try to apply the repeat rule
            if(just(repeatRegexRule) := repeatRegexes(sym, symProductions)) {
                productions[sym] = repeatRegexRule;
                newDirty += sym;
                log(ProgressDetailed(), "created iteration for <sym>");
            }
        }

        if(size(newDirty)>0) changed = true;
        dirty = newDirty;
    }

    return <changed, productions>;
}