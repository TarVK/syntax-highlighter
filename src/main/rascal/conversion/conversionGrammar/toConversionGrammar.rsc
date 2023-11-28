module conversion::conversionGrammar::toConversionGrammar

import IO;
import ParseTree;
import Grammar;
import Set;
import util::Maybe;
import List;
import String;
import lang::rascal::grammar::definition::Regular;

import Logging;
import conversion::conversionGrammar::ConversionGrammar;
import regex::PSNFATools;
import regex::Regex;
import regex::RegexCache;
import Scope;
import Warning;

@doc {
    Retrieves a conversion grammar that we can operate on to obtain a highlighting grammar
}
WithWarnings[ConversionGrammar] toConversionGrammar(type[Tree] g, Logger log) 
    = toConversionGrammar(grammar(g), log);
WithWarnings[ConversionGrammar] toConversionGrammar(Grammar grammar, Logger log) {
    log(Section(), "to conversion grammar");
    list[Warning] warnings = [];

    grammar = splitNewlines(grammar);
    grammar = makeRegularStubs(grammar);
    grammar = expandRegularSymbols(grammar);

    rel[Symbol, ConvProd] prods = {};
    for(def <- grammar.rules) {
        defProds = grammar.rules[def];

        // Note that def and lDef are not neccessarily the same, due to possible labels
        for(/p:prod(lDef, parts, attributes) <- defProds) {
            nonTermScopesSet = {parseScopes(scopes) | \tag("category"(scopes)) <- attributes};
            if(size(nonTermScopesSet)>1) warnings += multipleScopes(nonTermScopesSet, p);
            ScopeList nonTermScopes = [*scopes | scopes <- nonTermScopesSet];

            pureTermScopesSet = {parseScopes(scopes) | \tag("categoryTerm"(scopes)) <- attributes};
            if(size(pureTermScopesSet)>1) warnings += multipleTokens(pureTermScopesSet, p);
            ScopeList pureTermScopes = [*scopes | scopes <- pureTermScopesSet];
            termScopes = nonTermScopes + pureTermScopes;

            list[ConvSymbol] newParts = [];
            for(orSymb <- parts) {
                if(<newWarnings, symbols> := getConvSymbol(orSymb, p, termScopes, nonTermScopes)){
                    warnings += newWarnings;
                    for(warning <- warnings) log(Warning(), warning);
                    newParts += symbols;
                }
            }

            newProd = convProd(lDef, newParts);
            prods += <def, newProd>;
        }
    }

    // TODO: look into why multiple starts are allowed
    startSymbol = getOneFrom(grammar.starts);
    return <warnings, convGrammar(startSymbol, prods)>;
}

Grammar splitNewlines(Grammar gr) = visit(gr) {
    case \lit(text) => \seq([\lit(t) | t <- splitOnNewline(text)])
        when contains(text, "\n")
    case \cilit(text) => \seq([\cilit(t) | t <- splitOnNewline(text)])
        when contains(text, "\n")
};
list[str] splitOnNewline(str text) {
    parts = split("\n", text);
    for(i <- [0..size(parts)-1]) parts[i] += "\n";
    return parts;
}

WithWarnings[ConvSymbol] getConvSymbol(Symbol sym, Production prod, ScopeList termScopes, ScopeList nonTermScopes) {
    list[Warning] warnings = [];

    ConvSymbol rec(Symbol s) = rec(s, termScopes, nonTermScopes);
    ConvSymbol rec(Symbol s, ScopeList termScopes, ScopeList nonTermScopes){
        warningsAndResult = getConvSymbol(s, prod, termScopes, nonTermScopes);
        warnings += warningsAndResult.warnings;
        return warningsAndResult.result;
    }

    ConvSymbol getRegex(Regex exp) {
        // if(termScopes != []) exp = mark({scopeTag(toScopes(termScopes))}, exp);
        if(termScopes != []) 
            exp = mark({
                scopeTag(toScopes(termScopes[0..length]))
                | length <- [1..size(termScopes)+1]
            }, exp);
        exp =  meta(exp, {rascalProd(prod)});
        cachedExp = getCachedRegex(exp);
        return regexp(cachedExp);
    }

    ConvSymbol res;
    switch(sym) {
        case \char-class(cc): res = getRegex(character(cc));
        case \lit(text):
            res = getRegex(reduceConcatenation(concatenation([
                character(cc) | cc <- getCharRanges(text, false)
            ])));
        case \cilit(text): 
            res = getRegex(reduceConcatenation(concatenation([
                character(cc) | cc <- getCharRanges(text, true)
            ])));
        case \conditional(s, conditions): {
            res = rec(s);
            Maybe[ConvSymbol] r(Condition condition, Symbol conExp) {
                if([conExpOut] := rec(conExp, [], []))
                    return just(conExpOut);
                warnings += unresolvedModifier(condition, prod);
                return nothing();
            }

            for(c <- conditions) {
                switch(c) {
                    // Constraints should not recieve any scopes
                    case \delete(s2): res = delete(res, rec(s2, [], []));
                    case \follow(s2): res = follow(res, rec(s2, [], []));
                    case \precede(s2): res = precede(res, rec(s2, [], []));
                    case \not-follow(s2): res = notFollow(res, rec(s2, [], []));
                    case \not-precede(s2): res = notPrecede(res, rec(s2, [], []));
                    case \begin-of-line(): res = atStartOfLine(res);
                    case \end-of-line(): res = atEndOfLine(res);
                    default: {
                        warnings += unsupportedCondition(c, prod);
                    }
                }
            }
        }
        case \start(s): res = rec(s);
        default: res = ref(sym, nonTermScopes, {rascalProd(prod)});
    }

    return <warnings, res>;
}

@doc {
    For a given string, retrieves the characterclass list representing it. 
    E.g.:
    "hallo"
    =>
    [[range(104,104)], [range(97,97)],[range(108,108)], [range(108,108)], [range(111,111)]]
}
list[CharClass] getCharRanges(str text, bool caseInsensitive) {
    CharClass getCharClass(int c) {
        r = [range(c, c)];
        if(caseInsensitive && 97 <= c && c <= 122) { // 97 = a, 122 = z
            uc = c - 97 + 65; // 65 = A
            r += range(uc, uc);
        }
        return r;
    }

    return [getCharClass(charAt(text, i)) | i <- [0..size(text)]];
}
ScopeList parseScopes(str scopes) = split(",", scopes);
