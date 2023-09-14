module conversion::conversionGrammar::fromConversionGrammar

import Grammar;
import util::Maybe;
import ParseTree;
import String;

import Visualize; // For the annotate constructor
import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;
import regex::Regex;
import Scope;


@doc {
    Converts a conversion grammar into a standard grammar
}
Grammar fromConversionGrammar(ConversionGrammar gr) = fromConversionGrammar(gr, true);
Grammar fromConversionGrammar(convGrammar(\start, prods), bool addTags) {
    set[Production] outProds = {};
    for(<_, pr:convProd(lSym, parts)> <- prods) {
        newPartAndSources = [<p, s> | part <- parts, <p, s> := convSymbolToSymbol(part)];
        newParts = [p | <p, _> <- newPartAndSources];
        sources = {*s | <_, s> <- newPartAndSources};
        newProd = prod(lSym, newParts, {\tag(sources)});
        outProds += newProd;
    }
    return grammar({\start}, removeCustomSymbols(outProds));
}
tuple[Symbol, set[Production]] convSymbolToSymbol(ConvSymbol inp) {
    set[Production] prods = {};
    Symbol rec(ConvSymbol s) {
        <out, newProds> = convSymbolToSymbol(s);
        prods += newProds;
        return out;
    }
    Symbol out;

    switch(inp) {
        case symb(ref, scopes, sources): {
            prods += sources;
            out = ref;
            if(size(scopes)>0) out = annotate(out, {stringify(toScopes(scopes)), scopes});
        }
        case regexp(regex): {
            <sym, newProds> = regexToSymbol(removeCache(reduce(regex)));
            out = sym;
            prods += newProds;
        }
        case delete(from, del): 
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

tuple[Symbol, set[Production]] regexToSymbol(Regex inp) {
    eolR = eolRegex();
    solR = solRegex();

    set[Production] prods = {};
    Symbol rec(Regex r) {
        <out, newProds> = regexToSymbol(r);
        prods += newProds;
        return out;
    }
    Symbol out;
    
    switch(inp) {
        case meta(r, set[Production] newProds): {
            prods += newProds;
            out = rec(r);
        }

        // Special cases that lead to slightly easier to read grammars
        case alternation(\multi-iteration(r), Regex::empty()):
            out = \iter-star(rec(r));
        case alternation(Regex::empty(), \multi-iteration(r)): 
            out = \iter-star(rec(r));
        case concatenation(r, eolR): 
            out = \conditional(rec(r), {\end-of-line()});
        case concatenation(solR, r):
            out \conditional(rec(r), {\begin-of-line()});

        // Normal cases
        case never(): out = custom("never", seq([])); // TODO: could also use an empty range or smth: \char-class([])
        case Regex::empty(): out = ParseTree::\empty();
        case always(): out = \iter-start(complement(\char-class([])));
        case character(ranges): {
            if([range(k, k)]:=ranges)
                out = \lit(stringChar(k));
            else if([range(k, k), range(l, l)]:=ranges && l==k+40 && 101<=k && k<=132)
                out = \cilit(stringChar(l));
            else
                out = \char-class(ranges);
        }
        case lookahead(r, lookahead): 
            out = \conditional(rec(r), {\follow(rec(lookahead))});
        case lookbehind(r, lookbehind): 
            out = \conditional(rec(r), {\precede(rec(lookbehind))});
        case \negative-lookahead(r, lookahead): 
            out = \conditional(rec(r), {\not-follow(rec(lookahead))});
        case \negative-lookbehind(r, lookbehind): 
            out = \conditional(rec(r), {\not-precede(rec(lookbehind))});
        case subtract(r, removal): 
            out = \conditional(rec(r), {\delete(rec(removal))});
        case concatenation(head, tail): 
            out = simpSeq(rec(head), rec(tail));
        case alternation(opt1, opt2): 
            out = simpAlt(rec(opt1), rec(opt2));
        case \multi-iteration(r): 
            out = \iter(rec(r));
        case mark(tags, r): 
            out = annotate(rec(r), {
                Scope::stringify(s) 
                | scopeTag(s) <- tags, 
                s!=noScopes()
            } + tags);
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

&T removeCustomSymbols(&T grammar) = 
    visit(grammar) {
        case convSeq(parts) => \seq([s | p <- parts, s := convSymbolToSymbol(p)])
        case closedBy(sym, c) => \conditional(sym, {\follow(regexToSymbol(c))})
        case unionRec(recOptions) => custom("UR", \alt(recOptions))
    };