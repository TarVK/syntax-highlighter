module conversion::conversionGrammar::fromConversionGrammar

import Grammar;
import util::Maybe;
import ParseTree;
import String;

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
        case Regex::empty(): return just(ParseTree::\empty());
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