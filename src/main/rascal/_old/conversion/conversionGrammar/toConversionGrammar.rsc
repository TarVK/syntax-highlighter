module conversion::conversionGrammar::toConversionGrammar

import ParseTree;
import Grammar;
import Set;
import util::Maybe;
import List;
import String;
import lang::rascal::grammar::definition::Regular;

import conversion::util::RegexCache;
import conversion::conversionGrammar::ConversionGrammar;
import regex::PSNFATools;
import regex::Regex;
import Scope;
import Warning;

// Warnings that may be produced by conversion
data Warning = unresolvedModifier(ConvSymbol modifier, ConvProd production)
             | unsupportedCondition(Condition condition, Production inProd)
             | multipleTokens(set[ScopeList] tokens, Production inProd) // Warning because order can not be guaranteed, use a single token declaration instead
             | multipleScopes(set[ScopeList] scopes, Production inProd); // Warning because order can not be guaranteed, use a single scope declaration instead


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
            ScopeList nonTermScopes = [*scopes | scopes <- nonTermScopesSet];

            pureTermScopesSet = {parseScopes(scopes) | \tag("token"(scopes)) <- attributes};
            if(size(pureTermScopesSet)>1) warnings += multipleTokens(pureTermScopesSet, p);
            ScopeList pureTermScopes = [*scopes | scopes <- pureTermScopesSet];
            termScopes = nonTermScopes + pureTermScopes;

            list[ConvSymbol] newParts = [];
            for(orSymb <- parts) {
                if(<newWarnings, symbols> := getConvSymbol(orSymb, p, termScopes, nonTermScopes)){
                    warnings += newWarnings;
                    newParts += symbols;
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
WithWarnings[list[ConvSymbol]] getConvSymbol(Symbol sym, Production prod, ScopeList termScopes, ScopeList nonTermScopes) {
    list[Warning] warnings = [];

    list[ConvSymbol] rec(Symbol s) = rec(s, termScopes, nonTermScopes);
    list[ConvSymbol] rec(Symbol s, ScopeList termScopes, ScopeList nonTermScopes){
        warningsAndResult = getConvSymbol(s, prod, termScopes, nonTermScopes);
        warnings += warningsAndResult.warnings;
        return warningsAndResult.result;
    }

    ConvSymbol getRegex(Regex exp) {
        if(termScopes != []) exp = mark({scopeTag(toScopes(termScopes))}, exp);
        cachedExp = getCachedRegex(exp);
        return regexp(cachedExp);
    }

    list[ConvSymbol] res;
    switch(sym) {
        case \char-class(cc): res = [getRegex(character(cc))];
        case \lit(text): 
            res = [
                getRegex(reduceConcatenation(concatenation([
                    character(cc) | cc <- seq
                ])))
                | seq <- getCharRanges(text, false)
            ];
        case \cilit(text): 
            res = [
                getRegex(reduceConcatenation(concatenation([
                    character(cc) | cc <- seq
                ])))
                | seq <- getCharRanges(text, true)
            ];
        case \conditional(s, conditions): {
            parts = rec(s);
            if([exp] := parts) {
                Maybe[ConvSymbol] r(Condition condition, Symbol conExp) {
                    if([conExpOut] := rec(conExp, [], []))
                        return just(conExpOut);
                    warnings += unresolvedModifier(condition, prod);
                    return nothing();
                }

                for(c <- conditions) {
                    switch(c) {
                        // Modifiers should not recieve any scopes
                        case \delete(s2): if(just(e) := r(c, s2)) exp = delete(exp, e);
                        case \follow(s2): if(just(e) := r(c, s2)) exp = follow(exp, e);
                        case \precede(s2): if(just(e) := r(c, s2)) exp = precede(exp, e);
                        case \not-follow(s2): if(just(e) := r(c, s2)) exp = notFollow(exp, e);
                        case \not-precede(s2): if(just(e) := r(c, s2)) exp = notPrecede(exp, e);
                        case \begin-of-line(): exp = atStartOfLine(exp);
                        case \end-of-line(): exp = atEndOfLine(exp);
                        default: {
                            warnings += unsupportedCondition(c, prod);
                        }
                    }
                }

                res = [exp];
            } else {
                for(c <- conditions) 
                    warnings += unresolvedModifier(c, prod);
                res = parts;
            }
        }
        case \start(s): res = rec(s);
        default: res = [symb(sym, nonTermScopes)];
    }

    return <warnings, res>;
}

@doc {
    For a given string, retrieves the characterclass list representing it. And splits said list on newline characters such that a newline only ever occurs at the end of a sequence. 
    E.g.:
    "ha\nllo"
    =>
    [[[range(104,104)], [range(97,97)], [range(10,10)]], 
    [[range(108,108)], [range(108,108)], [range(111,111)]]]
}
list[list[CharClass]] getCharRanges(str text, bool caseInsensitive) {
    CharClass getCharClass(int c) {
        r = [range(c, c)];
        if(caseInsensitive && 97 <= c && c <= 122) { // 97 = a, 122 = z
            uc = c - 97 + 65; // 65 = A
            r += range(uc, uc);
        }
        return r;
    }

    list[list[int]] sequences = [];
    list[int] sequence = [];
    for(i <- [0..size(text)], c := charAt(text, i)){
        sequence += c;
        if(c==10) {
            sequences += [sequence];
            sequence = [];
        }
    }
    if(size(sequence)>0) sequences += [sequence];

    return [[getCharClass(c) | c <- seq] | seq <- sequences];
}
ScopeList parseScopes(str scopes) = split(",", scopes);
