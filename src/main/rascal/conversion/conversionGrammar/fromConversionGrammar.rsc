module conversion::conversionGrammar::fromConversionGrammar

import Grammar;
import util::Maybe;
import ParseTree;
import String;
import lang::rascal::grammar::definition::Characters;
import IO;

import Visualize; // For the annotate constructor
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::CustomSymbols;
import regex::RegexCache;
import regex::Regex;
import regex::RegexStripping;
import Scope;


@doc {
    Converts a conversion grammar into a standard grammar
}
Grammar fromConversionGrammar(ConversionGrammar gr) = fromConversionGrammar(gr, true);
Grammar fromConversionGrammar(convGrammar(\start, prods), bool useConversionSource) {
    set[Production] outProds = {};
    for(<_, pr:convProd(lSym, parts)> <- prods) {
        newPartAndSources = [<p, s> | part <- parts, <p, s> := convSymbolToSymbol(part)];
        newParts = [p | <p, _> <- newPartAndSources];
        sources = {*s | <_, s> <- newPartAndSources};
        newProd = prod(lSym, newParts, useConversionSource ? {\tag(pr)} : sources);
        outProds += newProd;
    }
    return grammar({\start}, removeCustomSymbols(outProds, prods));
}
tuple[Symbol, set[SourceProd]] convSymbolToSymbol(ConvSymbol inp) {
    set[SourceProd] prods = {};
    Symbol rec(ConvSymbol s) {
        <out, newProds> = convSymbolToSymbol(s);
        prods += newProds;
        return out;
    }
    Symbol out;

    switch(inp) {
        case ref(refSym, scopes, sources): {
            prods += sources;
            out = refSym;
            if(size(scopes)>0) out = annotate(out, {stringify(toScopes(scopes)), scopes});
        }
        case regexp(regex): {
            <sym, newProds> = regexToSymbolWithProds(removeRegexCache(reduce(regex)));
            out = sym;
            prods += newProds;
        }
        case delete(cSym, del): 
            out = \conditional(rec(cSym), {\delete(rec(del))});
        case follow(cSym, f): 
            out = \conditional(rec(cSym), {\follow(rec(f))});
        case notFollow(cSym, f):
            out = \conditional(rec(cSym), {\not-follow(rec(f))});
        case precede(cSym, p): 
            out = \conditional(rec(cSym), {\precede(rec(p))});
        case notPrecede(cSym, p): 
            out = \conditional(rec(cSym), {\not-precede(rec(p))});
        case atEndOfLine(cSym): 
            out = \conditional(rec(cSym), {\end-of-line()});
        case atStarrtOfLine(cSym):
            out = \conditional(rec(cSym), {\begin-of-line()});
    }

    return <out, prods>;
}

tuple[Symbol, set[SourceProd]] regexToSymbolWithProds(Regex inp) {
    set[SourceProd] prods = {};
    inp = visit(inp) {
        case meta(r, set[SourceProd] newProds): {
            prods += newProds;
            insert r;
        }
    }

    return <regexToSymbol(inp), prods>;
}
Symbol regexToSymbol(Regex inp) {
    eolR = eolRegex();
    solR = solRegex();

    Symbol out;    
    switch(inp) {
        case meta(r, _): 
            out = regexToSymbol(r);

        // Special cases that lead to slightly easier to read grammars
        case alternation(\multi-iteration(r), Regex::empty()):
            out = \iter-star(regexToSymbol(r));
        case regex::alternation(Regex::empty(), \multi-iteration(r)): 
            out = \iter-star(regexToSymbol(r));
        case concatenation(r, eolR): 
            out = \conditional(regexToSymbol(r), {\end-of-line()});
        case concatenation(solR, r):
            out \conditional(regexToSymbol(r), {\begin-of-line()});

        // Normal cases
        case never(): out = custom("never", seq([])); // TODO: could also use an empty range or smth: \char-class([])
        case Regex::empty(): out = ParseTree::\empty();
        case always(): out = \iter-star(complement(\char-class([])));
        case character(ranges): {
            if([range(k, k)]:=ranges)
                out = \lit(stringChar(k));
            else if([range(k, k), range(l, l)]:=ranges && l==k+40 && 101<=k && k<=132)
                out = \cilit(stringChar(l));
            else
                out = \char-class(ranges);
        }
        case lookahead(r, lookahead): 
            out = \conditional(regexToSymbol(r), {\follow(regexToSymbol(lookahead))});
        case lookbehind(r, lookbehind): 
            out = \conditional(regexToSymbol(r), {\precede(regexToSymbol(lookbehind))});
        case \negative-lookahead(r, lookahead): 
            out = \conditional(regexToSymbol(r), {\not-follow(regexToSymbol(lookahead))});
        case \negative-lookbehind(r, lookbehind): 
            out = \conditional(regexToSymbol(r), {\not-precede(regexToSymbol(lookbehind))});
        case subtract(r, removal): 
            out = \conditional(regexToSymbol(r), {\delete(regexToSymbol(removal))});
        case concatenation(head, tail): 
            out = simpSeq(regexToSymbol(head), regexToSymbol(tail));
        case alternation(opt1, opt2): 
            out = simpAlt(regexToSymbol(opt1), regexToSymbol(opt2));
        case \multi-iteration(r): 
            out = \iter(regexToSymbol(r));
        case mark(tags, r): 
            out = annotate(regexToSymbol(r), {
                Scope::stringify(s) 
                | scopeTag(s) <- tags, 
                s!=noScopes()
            } + tags);
        default:{
            println("Missed a case in regexToSymbol: <inp>");
        }            
    }
    return out;
}
Symbol simpSeq(\seq(a), \seq(b)) = simpSeq([*a, *b]);
Symbol simpSeq(Symbol a, \seq(b)) = simpSeq([a, *b]);
Symbol simpSeq(\seq(a), Symbol b) = simpSeq([*a, b]);
default Symbol simpSeq(Symbol a, Symbol b) = simpSeq([a, b]);
Symbol simpSeq([*p, lit(a), lit(b), *s]) = simpSeq([*p, lit(a+b), *s]);
Symbol simpSeq([*p, cilit(a), cilit(b), *s]) = simpSeq([*p, cilit(a+b), *s]);
Symbol simpSeq(l) = [f]:=l ? f : \seq(l);

Symbol simpAlt(\alt(a), \alt(b)) = \alt({*a, *b});
Symbol simpAlt(Symbol a, \alt(b)) = \alt({a, *b});
Symbol simpAlt(\alt(a), Symbol b) = \alt({*a, b});
default Symbol simpAlt(Symbol a, Symbol b) = \alt({a, b});

set[Production] removeCustomSymbols(set[Production] prods, rel[Symbol, ConvProd] orProds) {
    int id = 0;
    map[ConvSymbol, Symbol] nfas = ();
    Symbol convSymbolToSymbolWithNFA(ConvSymbol convSym) {
        if(regexNfa(nfa) := convSym) {
            if(convSym in nfas) return nfas[convSym];
            sym = annotate(sort("NFA<id>"), {nfa});
            id += 1;
            nfas[convSym] = sym;
            return sym;
        }
        return convSymbolToSymbol(convSym)<0>;
    }

    
    prods = visit(prods) {
        case cs:convSeq(parts): {
            // Follow aliases
            while({convProd(_, orParts)} := orProds[cs], [ref(sym, [], {})] := orParts) {
                cs = sym;
            }

            // Replace all regexNfas by regexes when possible
            if({convProd(_, orParts)} := orProds[cs], size(parts)==size(orParts)) {
                for(i <- [0..size(orParts)]) {
                    if(regexNfa(_) := parts[i], regexp(_) := orParts[i]) 
                        parts[i] = orParts[i];
                }
            }

            insert convSeq(parts);
        }
    };

    return visit(prods) {
        case cs:convSeq(parts) => \seq([s | p <- parts, s := convSymbolToSymbolWithNFA(p)])
        case closed(a, b) =>  custom("C", \seq([a, b]))
        case unionRec(recOptions) => custom("UR", \alt(recOptions))
    };
}