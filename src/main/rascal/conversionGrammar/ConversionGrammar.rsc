module conversionGrammar::ConversionGrammar

import lang::rascal::grammar::definition::Regular;
import ParseTree;
import Grammar;
import Set;
import Map;
import String;

import Scope;
import Warning;
import regex::Regex;

data ConversionGrammar = convGrammar(Symbol \start, rel[Symbol, ConvProd] productions);

@doc {
    The base production rule data for a conversion grammar:
    - symb: The identifier of the production, a non-terminal symbol
    - parts: The right handside of the production, consisting of non-terminals and terminal regular expressions
    - sources: The production(s) that were used to derive this production from
}
data ConvProd = convProd(Symbol symb, list[ConvSymbol] parts, set[SourceProd] sources);
data SourceProd = convProdSource(ConvProd convProd)
                | origProdSource(Production origProd);

data ConvSymbol = symb(Symbol ref, Scopes scopes)                   // Non-terminal, with the scopes to assign it
                | delete(ConvSymbol from, ConvSymbol del)           // Deleting one non-terminal from another non-terminal
                | follow(ConvSymbol sym, ConvSymbol follow)         // Matchimy sym only if followed by follow
                | notFollow(ConvSymbol sym, ConvSymbol follow)      // Matchimy sym only if not followed by follow
                | precede(ConvSymbol sym, ConvSymbol precede)       // Matchimy sym only if preceded by precede
                | notPrecede(ConvSymbol sym, ConvSymbol precede)    // Matchimy sym only if not preceded by precede
                | regexp(Regex regex);                              // Terminal

// Allow sources to be specified within an expression, to track how a regular expression was obtained
data Regex = regexSource(Regex r, set[ConvProd] prods);

@doc {
    Retrieves a conversion grammar that we can operate on to obtain a highlighting grammar
}
WithWarnings[ConversionGrammar] toConversionGrammar(type[Tree] g) = toConversionGrammar(grammar(g));
WithWarnings[ConversionGrammar] toConversionGrammar(Grammar grammar) {
    list[Warning] warnings = [];

    grammar = makeRegularStubs(grammar);
    grammar = expandRegularSymbols(grammar);

    rel[Symbol, ConvProd] prods = {};
    for(/p:prod(def, parts, attributes) <- range(grammar.rules)) {
        nonTermScopes = [parseScope(scope) | \tag("scope"(scope)) <- attributes];
        termScopes = nonTermScopes + [parseScope(scope) | \tag("token"(scope)) <- attributes];

        list[ConvSymbol] newParts = [];
        for(orSymb <- parts) {
            if(<newWarnings, symb> := getConvSymbol(orSymb, p, termScopes, nonTermScopes)){
                warnings += newWarnings;
                newParts += symb;
            }
        }

        newProd = convProd(def, newParts, {origProdSource(p)});
        prods += <def, newProd>;
    }

    startSymbol = getOneFrom(grammar.starts);
    return <warnings, convGrammar(startSymbol, prods)>;
}

data Warning = unsupportedCondition(Condition condition, Production inProd);
WithWarnings[ConvSymbol] getConvSymbol(Symbol sym, Production prod, Scopes termScopes, Scopes nonTermScopes) {
    list[Warning] warnings = [];
    ConvSymbol rec(Symbol s){
        warningsAndResult = getConvSymbol(s, prod, termScopes, nonTermScopes);
        warnings += warningsAndResult.warnings;
        return warningsAndResult.result;
    }

    ConvSymbol getRegex(Regex exp) {
        if(size(termScopes) > 0) exp = scoped(termScopes, exp);
        return regexp(exp);
    }

    ConvSymbol res;
    switch(sym) {
        case \char-class(cc): res = getRegex(character(cc));
        case \lit(text): res = getRegex(concatenation([character(c) | c <- getCharRanges(text, false)]));
        case \cilit(text): res = getRegex(concatenation([character(c) | c <- getCharRanges(text, true)]));
        case \conditional(s, conditions): {
            res = rec(s);
            for(c <- conditions) {
                switch(c) {
                    case \delete(s2): res = delete(res, rec(s2));
                    case \follow(s2): res = follow(res, rec(s2));
                    case \precede(s2): res = precede(res, rec(s2));
                    case \not-follow(s2): res = notFollow(res, rec(s2));
                    case \not-precede(s2): res = notPrecede(res, rec(s2));
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
Scope parseScope(str scope) = split(".", scope);