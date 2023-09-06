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
    for(<_, pr:convProd(lSym, parts, sources)> <- prods) {
        newParts = [p | part <- parts, p := convSymbolToSymbol(part)];
        newProd = prod(lSym, newParts, {\tag(pr)});
        outProds += newProd;
    }
    return grammar({\start}, removeCustomSymbols(outProds));
}
Symbol convSymbolToSymbol(ConvSymbol inp) {
    switch(inp) {
        case symb(ref, scopes): {
            if(size(scopes)>0)
                return annotate(ref, {stringify(scopes), scopes});
            return ref;
        }
        case delete(from, del): 
            return \conditional(convSymbolToSymbol(cSym), {\delete(convSymbolToSymbol(del))});
        case follow(cSym, f): 
            return \conditional(convSymbolToSymbol(cSym), {\follow(convSymbolToSymbol(f))});
        case notFollow(cSym, f):
            return \conditional(convSymbolToSymbol(cSym), {\not-follow(convSymbolToSymbol(f))});
        case precede(cSym, p): 
            return \conditional(convSymbolToSymbol(cSym), {\precede(convSymbolToSymbol(p))});
        case notPrecede(cSym, p): 
            return \conditional(convSymbolToSymbol(cSym), {\not-precede(convSymbolToSymbol(p))});
        case atEndOfLine(cSym): 
            return \conditional(convSymbolToSymbol(cSym), {\end-of-line()});
        case atStarrtOfLine(cSym):
            return \conditional(convSymbolToSymbol(cSym), {\begin-of-line()});
        case regexp(regex): return regexToSymbol(removeCache(reduce(regex)));
    }
}

Symbol regexToSymbol(Regex inp) {
    eolR = eolRegex();
    solR = solRegex();
    
    switch(inp) {
        // Special cases that lead to slightly easier to read grammars
        case alternation(\multi-iteration(r), Regex::empty()):
            return \iter-star(regexToSymbol(r));
        case alternation(Regex::empty(), \multi-iteration(r)): 
            return \iter-star(regexToSymbol(r));
        case concatenation(r, eolR): 
            return just(\conditional(regexToSymbol(r), {\end-of-line()}));
        case concatenation(solR, r):
            return \conditional(regexToMaybeSymbol(r), {\begin-of-line()});

        // Normal cases
        case never(): return custom("never", seq([])); // TODO: could also use an empty range or smth: \char-class([])
        case Regex::empty(): return ParseTree::\empty();
        case always(): return \iter-start(complement(\char-class([])));
        case character(ranges): {
            if([range(k, k)]:=ranges)
                return \lit(stringChar(k));
            if([range(k, k), range(l, l)]:=ranges && l==k+40 && 101<=k && k<=132)
                return \cilit(stringChar(l));
            return \char-class(ranges);
        }
        case lookahead(r, lookahead): 
            return \conditional(regexToSymbol(r), {\follow(regexToSymbol(lookahead))});
        case lookbehind(r, lookbehind): 
            return \conditional(regexToSymbol(r), {\precede(regexToSymbol(lookbehind))});
        case \negative-lookahead(r, lookahead): 
            return \conditional(regexToSymbol(r), {\not-follow(regexToSymbol(lookahead))});
        case \negative-lookbehind(r, lookbehind): 
            return \conditional(regexToSymbol(r), {\not-precede(regexToSymbol(lookbehind))});
        case subtract(r, removal): 
            return \conditional(regexToSymbol(r), {\delete(regexToSymbol(removal))});
        case concatenation(head, tail): 
            return simpSeq(regexToSymbol(head), regexToSymbol(tail));
        case alternation(opt1, opt2): 
            return simpAlt(regexToSymbol(opt1), regexToSymbol(opt2));
        case \multi-iteration(r): 
            return \iter(regexToSymbol(r));
        case mark(tags, r): 
            return annotate(regexToSymbol(r), {
                Scope::stringify(s) 
                | scopeTag(s) <- tags, 
                size(s)>0
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