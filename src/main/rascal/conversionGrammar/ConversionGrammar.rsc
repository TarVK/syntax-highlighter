module conversionGrammar::ConversionGrammar

extend ParseTree;

import lang::rascal::grammar::definition::Regular;
import ParseTree;
import Grammar;
import Set;
import Map;
import List;
import String;
import util::Maybe;
import IO;
import Grammar;
import lang::rascal::grammar::definition::Characters;

import Visualize;
import conversionGrammar::RegexCache;
import regex::Regex;
import regex::PSNFATools;
import Scope;
import Warning;

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
                | follow(ConvSymbol sym, ConvSymbol follow)         // Matching sym only if followed by follow
                | notFollow(ConvSymbol sym, ConvSymbol follow)      // Matching sym only if not followed by follow
                | precede(ConvSymbol sym, ConvSymbol precede)       // Matching sym only if preceded by precede
                | notPrecede(ConvSymbol sym, ConvSymbol precede)    // Matching sym only if not preceded by precede
                | atEndOfLine(ConvSymbol sym)                       // Matching sym only if it's at the end of the line
                | atStartOfLine(ConvSymbol sym)                     // Matching sym only if it's at the start of the line
                | regexp(Regex regex);                              // Terminal
// Note that after regex conversion is performed, all modifiers are gone. Hence only `symb` and `regexp` is left in the grammar.

// Allow sources to be specified within an expression, to track how a regular expression was obtained
data Regex = regexSource(Regex r, set[ConvProd] prods);

alias ProdMap = map[Symbol, set[ConvProd]];

// Warnings that may be produced by conversion
data Warning = unsupportedCondition(Condition condition, Production inProd)
             | multipleTokens(set[Scopes] tokens, Production inProd) // Warning because order can not be guaranteed, use a single token declaration instead
             | multipleScopes(set[Scopes] scopes, Production inProd); // Warning because order can not be guaranteed, use a single scope declaration instead

@doc {
    Replaces the given production in the grammar with the new production
}
ConversionGrammar replaceProduction(ConversionGrammar grammar, ConvProd old, ConvProd new) 
    = addProduction(removeProduction(grammar, old), new);

@doc {
    Removes a production from the given grammar
}
ConversionGrammar removeProduction(ConversionGrammar grammar, ConvProd old) {
    grammar.productions = grammar.productions - <old.symb, old>;
    return grammar;
}

@doc {
    Adds a production to the given grammar
}
ConversionGrammar addProduction(ConversionGrammar grammar, ConvProd new) {
    grammar.productions = grammar.productions + <new.symb, new>;
    return grammar;
}



@doc {
    Checks whether two productions define the same language/tokenization from the given index forward
}
bool equalsAfter(a:convProd(_, pa, _), b:convProd(_, pb, _), int index) {
    if(size(pa) != size(pb)) return false;

    for(i <- [index..size(pa)]) {
        sa = pa[i];
        sb = pb[i];
        if(sa == sb) continue;
        if(regexp(ra) := sa && regexp(rb) := sb) 
            if(equals(ra, rb)) continue;

        return false;
    }

    return true;
}

@doc {
    Removes the intermediate conversion productions from the grammar, and only keeps the base grammar sources
}
&T stripConvSources(&T grammar) {
    return visit (grammar) {
        case set[SourceProd] sources => 
            {s | s:origProdSource(_) <- sources} 
            + {*s | convProdSource(convProd(_, _, s)) <- sources}
    }
}

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

@doc {
    Converts a conversion grammar into a standard grammar
}
Grammar fromConversionGrammar(ConversionGrammar gr) = fromConversionGrammar(gr, true);
Grammar fromConversionGrammar(convGrammar(\start, prods), bool addTags) {
    set[Production] outProds = {};
    for(<_, pr:convProd(lSym, parts, sources)> <- prods) {
        newParts = [p | part <- parts, just(p) := convSymbolToSymbol(part)];
        newProd = prod(lSym, newParts, {\tag(pr)});
        outProds += newProd;
    }
    return grammar({\start}, outProds);
}
Maybe[Symbol] convSymbolToSymbol(ConvSymbol inp) {
    switch(inp) {
        case symb(ref, scopes): {
            if(size(scopes)>0)
                return just(annotate(ref, {stringify(scopes), scopes}));
            return just(ref);
        }
        case delete(from, del): {
            mFromSym = convSymbolToSymbol(from);
            if(just(fromSym) := mFromSym && just(delSym) := convSymbolToSymbol(del)) 
                return just(\conditional(fromSym, {\delete(delSym)}));
            return mFromSym;
        }
        case follow(cSym, f): {
            mSym = convSymbolToSymbol(cSym);
            if(just(sym) := mSym && just(followSym) := convSymbolToSymbol(f)) 
                return just(\conditional(sym, {\follow(followSym)}));
            return mSym;
        }
        case notFollow(cSym, f): {
            mSym = convSymbolToSymbol(cSym);
            if(just(sym) := mSym && just(followSym) := convSymbolToSymbol(f)) 
                return just(\conditional(sym, {\not-follow(followSym)}));
            return mSym;
        }
        case precede(cSym, p): {
            mSym = convSymbolToSymbol(cSym);
            if(just(sym) := mSym && just(precedeSym) := convSymbolToSymbol(p)) 
                return just(\conditional(sym, {\precede(precedeSym)}));
            return mSym;
        }
        case notPrecede(cSym, p): {
            mSym = convSymbolToSymbol(cSym);
            if(just(sym) := mSym && just(precedeSym) := convSymbolToSymbol(p)) 
                return just(\conditional(sym, {\not-precede(precedeSym)}));
            return mSym;
        }
        case atEndOfLine(cSym): {
            if(just(sym) := convSymbolToSymbol(cSym)) 
                return just(\conditional(sym, {\end-of-line()}));
            return nothing();
        }
        case atStarrtOfLine(cSym): {
            if(just(sym) := convSymbolToSymbol(cSym))
                return just(\conditional(sym, {\begin-of-line()}));
            return nothing();
        }
        case regexp(regex): return regexToSymbol(removeCache(reduce(regex)));
    }
    return nothing();
}
Maybe[Symbol] regexToSymbol(Regex inp) {
    eolR = eolRegex();
    solR = solRegex();
    
    switch(inp) {
        // Special cases that lead to slightly easier to read grammars
        case alternation(\multi-iteration(r), Regex::empty()): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym)
                return just(\iter-star(rSym));
            return nothing();
        }
        case alternation(Regex::empty(), \multi-iteration(r)): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym)
                return just(\iter-star(rSym));
            return nothing();
        }
        case concatenation(r, eolR): {
            if(just(rSym) := regexToSymbol(r))
                return just(\conditional(rSym, {\end-of-line()}));
            return nothing();
        }
        case concatenation(solR, r): {
            if(just(rSym) := regexToSymbol(r))
                return just(\conditional(rSym, {\begin-of-line()}));
            return nothing();
        }

        // Normal cases
        case never(): return nothing();
        case Regex::empty(): return just(\empty());
        case always(): return just(\iter-start(complement(\char-class([]))));
        case character(ranges): {
            if([range(k, k)]:=ranges)
                return just(\lit(stringChar(k)));
            if([range(k, k), range(l, l)]:=ranges && l==k+40 && 101<=k && k<=132)
                return just(\cilit(stringChar(l)));
            return just(\char-class(ranges));
        }
        case lookahead(r, lookahead): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym && just(laSym) := regexToSymbol(lookahead)) 
                return just(\conditional(rSym, {\follow(laSym)}));
            return mRSym;
        }
        case lookbehind(r, lookbehind): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym && just(lbSym) := regexToSymbol(lookbehind)) 
                return just(\conditional(rSym, {\precede(lbSym)}));
            return mRSym;
        }
        case \negative-lookahead(r, lookahead): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym && just(laSym) := regexToSymbol(lookahead)) 
                return just(\conditional(rSym, {\not-follow(laSym)}));
            return mRSym;
        }
        case \negative-lookbehind(r, lookbehind): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym && just(lbSym) := regexToSymbol(lookbehind)) 
                return just(\conditional(rSym, {\not-precede(lbSym)}));
            return mRSym;
        }
        case subtract(r, removal): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym && just(removalSym) := regexToSymbol(removal)) 
                return just(\conditional(rSym, {\delete(removalSym)}));
            return mRSym;
        }
        case concatenation(head, tail): {
            mHeadSym = regexToSymbol(head);
            mTailSym = regexToSymbol(tail);
            if(just(headSym) := mHeadSym){
                if(just(tailSym) := mTailSym) return just(simpSeq(headSym, tailSym));
                return just(headSym);
            }
            return mTailSym;
        }
        case alternation(opt1, opt2): {
            mOpt1Sym = regexToSymbol(opt1);
            mOpt2Sym = regexToSymbol(opt2);
            if(just(opt1Sym) := mOpt1Sym){
                if(just(opt2Sym) := mOpt2Sym) return just(simpAlt(opt1Sym, opt2Sym));
                return just(opt1Sym);
            }
            return mOpt2Sym;
        }
        case \multi-iteration(r): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym)
                return just(\iter(rSym));
            return nothing();
        }
        case mark(tags, r): {
            mRSym = regexToSymbol(r);
            if(just(rSym) := mRSym)
                return just(annotate(rSym, {
                    Scope::stringify(s) 
                    | scopeTag(s) <- tags, 
                    size(s)>0
                } + tags));
            return nothing();
        }
    }
    return nothing();
}
Symbol simpSeq(Symbol a, Symbol b) = simpSeq([a, b]);
Symbol simpSeq(Symbol a, \seq(b)) = simpSeq([a, *b]);
Symbol simpSeq(\seq(a), Symbol b) = simpSeq([*a, b]);
Symbol simpSeq(\seq(a), \seq(b)) = simpSeq([*a, *b]);
Symbol simpSeq([*p, lit(a), lit(b), *s]) = simpSeq([*p, lit(a+b), *s]);
Symbol simpSeq([*p, cilit(a), cilit(b), *s]) = simpSeq([*p, cilit(a+b), *s]);
Symbol simpSeq(l) = [f]:=l ? f : \seq(l);
Symbol simpAlt(Symbol a, Symbol b) = \alt({a, b});
Symbol simpAlt(Symbol a, \alt(b)) = \alt({a, *b});
Symbol simpAlt(\alt(a), Symbol b) = \alt({*a, b});
Symbol simpAlt(\alt(a), \alt(b)) = \alt({*a, *b});

// utils
value stripSources(value anything) = visit (anything) {
    case convProd(lDef, parts, _) => convProd(lDef, parts, {})
};

Symbol getWithoutLabel(label(_, sym)) = sym;
default Symbol getWithoutLabel(Symbol sym) = sym;