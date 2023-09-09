module mapping::textmate::createTextmateGrammar

import List;

import util::List;
import regex::RegexTypes;
import mapping::intermediate::scopeGrammar::ScopeGrammar;
import mapping::textmate::TextmateGrammar;
import mapping::common::HighlightGrammarData;
import mapping::common::stringifyOnigurumaRegex;
import Warning;
import Scope;

@doc {
    Creates a textmate grammar from the given scope grammar, and additional highlighting grammar data
}
TextmateGrammar createTextmateGrammar(ScopeGrammar grammar, HighlightGrammarData hlData) {
    list[Warning] warnings = [];

    map[str, TextmatePattern] repository = ();
    for(sym <- grammar.productions) {
        list[TextmatePattern] patterns = [];

        for(prod <- grammar.productions[sym]) {
            if(tokenProd(<r, scopes>) := prod) {
                patterns += tokenPattern(stringifyOnigurumaRegex(r), createCaptures(scopes));
            } else if(scopeProd(<open, openScopes>, <ref, refScope>, <close, closeScopes>) := prod) {
                or = stringifyOnigurumaRegex(open);
                os = createCaptures(openScopes);
                cr = stringifyOnigurumaRegex(close);
                cs = createCaptures(closeScopes);

                if([] := refScope) patterns += scopePattern(or, cr, os, cs, [include("#<ref>")]);
                else patterns += scopePattern(or, cr, os, cs, [include("#<ref>")], contentName=stringify(refScope, "."));
            } else if(inclusion(ref) := prod) {
                patterns += include("#<ref>");
            }
        }

        if([pattern] := patterns) repository[sym] = pattern;
        else                      repository[sym] = include(patterns);
    }

    Regex openBrackets = alternation([open | <open, _> <- hlData.brackets]);
    Regex closeBrackets = alternation([close | <_, close> <- hlData.brackets]);

    return textmateGrammar(
        hlData.name,
        hlData.scopeName,
        [include("#<grammar.\start>")],
        repository = repository,
        fileTypes = hlData.fileTypes,
        foldingStart = stringifyOnigurumaRegex(openBrackets),
        foldingEnd = stringifyOnigurumaRegex(closeBrackets),
        firstLineMatch = hlData.firstLineMatch
    );
}

Captures createCaptures(list[Scope] scopes) {
    Captures captures = ();
    for(i <- [0..size(scopes)]) 
        captures["<i+1>"] = captureExp(stringify(scopes[i], "."));
    return captures;
}