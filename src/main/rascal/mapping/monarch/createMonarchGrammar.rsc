module mapping::monarch::createMonarchGrammar

import Map;
import List;
import IO;

import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::intermediate::PDAGrammar::PDAGrammar;
import mapping::monarch::MonarchGrammar;
import mapping::common::HighlightGrammarData;
import mapping::common::stringifyOnigurumaRegex;
import mapping::monarch::splitMarkedUnions;
import mapping::intermediate::scopeGrammar::extractRegexScopes;
import regex::RegexTypes;
import Scope;

@doc {
    Creates a monarch grammar from the given PDA grammar, and additional highlighting grammar data

    TODO: look into the end of line nuances with regular expressions in Monarch, doesn't seem to work the same as in textmate
}
MonarchGrammar createMonarchGrammar(PDAGrammar grammar) {
    map[str, MonarchStateDefinition] tokenizer = ();
    
    <grammar, replacements> = replaceReservedSymbols(grammar);
    for(sym <- grammar.productions) {
        list[MonarchRule] outProds = [];

        symProds = grammar.productions[sym];
        for(prod <- symProds) {
            if(inclusion(s) := prod)
                outProds += includeRule(replaceReserved(s, replacements));
            else if(tokenProd(uRegex) := prod)
                for(<regex, scopes> <- splitOptionalCaptureGroups(uRegex))
                    outProds += tokenRule(
                        stringifyOnigurumaRegex(regex), 
                        [token(scope) | scope <- scopes]
                    );
            else if(pushProd(uRegex, push) := prod)
                for(<regex, scopes> <- splitOptionalCaptureGroups(uRegex))
                    outProds += tokenRule(
                        stringifyOnigurumaRegex(regex),
                        [
                            stateChange(scope, "@<replaceReserved(push, replacements)>") 
                            | scope <- scopes
                        ]                    
                    );
            else if(popProd(uRegex) := prod)
                for(<regex, scopes> <- splitOptionalCaptureGroups(uRegex))
                    outProds += tokenRule(
                        stringifyOnigurumaRegex(regex),
                        [
                            stateChange(scope, "@pop") 
                            | scope <- scopes
                        ]                    
                    );
        }

        tokenizer[sym] = outProds;
    }

    return monarchGrammar(grammar.\start, tokenizer);
}

list[str] reservedSymbols = ["pop", "push", "popall"];
tuple[PDAGrammar, map[str, str]] replaceReservedSymbols(PDAGrammar grammar) {
    map[str, str] replacements = ();

    for(reserved <- reservedSymbols) {
        if(reserved in grammar.productions) {
            int id = 0;
            while("<reserved>_<id>" in grammar.productions) id += 1;
            reservedReplacement = "<reserved>_<id>";
            grammar.productions[reservedReplacement] = grammar.productions[root];
            grammar.productions = delete(grammar.productions, reserved);
            replacements[reserved] = reservedReplacement;

            if(grammar.\start == reserved) grammar.\start = reservedReplacement;
        }
    }

    return <grammar, replacements>;
}
str replaceReserved(str symbol, map[str, str] replacements) 
    = symbol in replacements ? replacements[symbol] : symbol;

@doc {
    Splits the optional capture groups, such that every output regex always matches all of the capture groups. The union of these output scoped regexes will be equivalent to the input scoped regex. 
}
list[ScopedRegex] splitOptionalCaptureGroups(<regex, scopes>) {
    expressions = splitMarkedUnions(regex);
    scopedExpressions = visit(expressions) {
        case mark(tags, r): {
            newTags = {
                scopeTag(toScopes([scopes[i]])) 
                | captureGroup(i) <- tags, 
                0 <= i && i < size(scopes)
            };
            if(newTags != {}) insert mark(newTags, r);
            insert r;
        }
    };
    if(scopedExpressions==[]) println(regex);
    return [extractRegexScopes(scopedExpression) | scopedExpression <- scopedExpressions];
}