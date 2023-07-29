module conversion::conversionGrammar::toConversionGrammar

import ParseTree;
import Grammar;
import Set;
import List;
import String;
import lang::rascal::grammar::definition::Regular;

import conversion::util::RegexCache;
import conversion::conversionGrammar::ConversionGrammar;
import regex::PSNFATools;
import regex::Regex;
import Scope;
import Warning;

@doc {
    Retrieves a conversion grammar that we can operate on to obtain a highlighting grammar
}
WithWarnings[ConversionGrammar] toConversionGrammar(type[Tree] g) = toConversionGrammar(grammar(g));
WithWarnings[ConversionGrammar] toConversionGrammar(Grammar grammar) {
    list[Warning] warnings = [];

    grammar = makeRegularStubs(grammar);
    grammar = expandRegularSymbols(grammar);

    rel[Symbol, ConvProd] prods = {};
    for(def <- grammar.rules) {
        defProds = grammar.rules[def];

        // Note that def and lDef are not neccessarily the same, due to possible labels
        for(/p:prod(lDef, parts, attributes) <- defProds) {
            nonTermScopesSet = {parseScopes(scopes) | \tag("scope"(scopes)) <- attributes};
            if(size(nonTermScopesSet)>1) warnings += multipleScopes(nonTermScopesSet, p);
            nonTermScopes = [*scopes | scopes <- nonTermScopesSet];

            pureTermScopesSet = {parseScopes(scopes) | \tag("token"(scopes)) <- attributes};
            if(size(pureTermScopesSet)>1) warnings += multipleTokens(pureTermScopesSet, p);
            pureTermScopes = [*scopes | scopes <- pureTermScopesSet];
            termScopes = nonTermScopes + pureTermScopes;

            list[ConvSymbol] newParts = [];
            for(orSymb <- parts) {
                if(<newWarnings, symb> := getConvSymbol(orSymb, p, termScopes, nonTermScopes)){
                    warnings += newWarnings;
                    newParts += symb;
                }
            }

            newProd = convProd(lDef, newParts, {origProdSource(p)});
            prods += <def, newProd>;
        }
    }

    // TODO: look into why multiple starts are allowed
    startSymbol = getOneFrom(grammar.starts);
    return <warnings, convGrammar(startSymbol, prods)>;
}
WithWarnings[ConvSymbol] getConvSymbol(Symbol sym, Production prod, Scopes termScopes, Scopes nonTermScopes) {
    list[Warning] warnings = [];

    ConvSymbol rec(Symbol s) = rec(s, termScopes, nonTermScopes);
    ConvSymbol rec(Symbol s, Scopes termScopes, Scopes nonTermScopes){
        warningsAndResult = getConvSymbol(s, prod, termScopes, nonTermScopes);
        warnings += warningsAndResult.warnings;
        return warningsAndResult.result;
    }

    ConvSymbol getRegex(Regex exp) {
        if(size(termScopes) > 0) exp = mark({scopeTag(termScopes)}, exp);
        <cachedExp, _, _> = cachedRegexToPSNFAandContainsScopes(exp);
        return regexp(cachedExp);
    }

    ConvSymbol res;
    switch(sym) {
        case \char-class(cc): res = getRegex(character(cc));
        case \lit(text): res = getRegex(reduceConcatenation(concatenation(
            [character(c) | c <- getCharRanges(text, false)])));
        case \cilit(text): res = getRegex(reduceConcatenation(concatenation(
            [character(c) | c <- getCharRanges(text, true)])));
        case \conditional(s, conditions): {
            res = rec(s);
            for(c <- conditions) {
                switch(c) {
                    // Modifiers should not recieve any scopes
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
        default: res = symb(sym, nonTermScopes);
    }

    return <warnings, res>;
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
    return [getCharClass(c) | i <- [0..size(text)], c := charAt(text, i)];
}
Scopes parseScopes(str scopes) = [split(".", scope) | scope <- split(",", scopes)];
