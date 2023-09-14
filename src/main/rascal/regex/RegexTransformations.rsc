module regex::RegexTransformations

import ParseTree;
import util::Maybe;

import regex::util::charClass;
import regex::RegexTypes;
import regex::Regex;

@doc {
    Retrieves a regular expression that doesn't include the empty string, as well as possibly a full empty match, and/or an empty match that restricts the context, such that the alternation of these expressions is equivalent to the input expression. Also puts the corresponding PSNFA in an expression cache. 

    Preconditions:
        - regex is in reduced form
    
    Postconditions:
        - L(regex) = L(nonEmpty + empty + emptyWithRestrictions)
        - nonEmpty and emptyWithRestrictions are in reduced form
        - empty == never() || cached(empty(), _, _) := empty
        - !acceptsEmpty(regex)
        - ∀ p,w,s ∈ E* . ((p, w, s) ∈ L(emptyWithRestrictions)) => w == e  (I.e. emptyWithRestrictions only matches empty strings)
}
tuple[
    Regex nonEmpty, 
    Regex empty, 
    Regex emptyWithRestrictions
] factorOutEmpty(Regex r) {
    list[Regex] nonEmptyOptions = [];
    bool isEmpty = false;
    list[Regex] emptyRestrOptions = [];

    switch(r) {
        case never(): return <never(), never(), never()>;
        case empty(): return <never(), empty(), never()>;
        case always(): return <\multi-iteration(character(anyCharClass())), empty(), never()>;
        case character(ranges): return <character(ranges), never(), never()>;
        case meta(e, v): return cacheMeta(_, _) := v ? factorOutEmpty(e) : meta(factorOutEmpty(e), v);
        case concatenation(e1, e2): {
            <main1, empty1, emptyRestr1> = factorOutEmpty(e1);
            <main2, empty2, emptyRestr2> = factorOutEmpty(e2);

            if(main1 != never()) {
                if(main2 != never())       nonEmptyOptions += concatenation(main1, main2);
                if(empty2 != never())      nonEmptyOptions += main1;
                if(emptyRestr2 != never()) nonEmptyOptions += concatenation(main1, emptyRestr2);
            }
            if(main2 != never()) {
                if(empty1 != never())      nonEmptyOptions += main2;
                if(emptyRestr1 != never()) nonEmptyOptions += concatenation(emptyRestr1, main2);
            }

            if(empty1 != never())
                if(empty2 != never())      isEmpty = true;

            if(emptyRestr1 != never()) {
                if(empty2 != never())      emptyRestrOptions += emptyRestr1;
                if(emptyRestr2 != never()) emptyRestrOptions += concatenation(emptyRestr1, emptyRestr2);
            }
            if(emptyRestr2 != never())
                if(empty1 != never())      emptyRestrOptions += emptyRestr2;
        }
        case alternation(e1, e2): {
            <main1, empty1, emptyRestr1> = factorOutEmpty(e1);
            <main2, empty2, emptyRestr2> = factorOutEmpty(e2);

            if(main1 != never())           nonEmptyOptions += main1;
            if(main2 != never())           nonEmptyOptions += main2;
            if(empty1 != never())          isEmpty = true;
            if(empty2 != never())          isEmpty = true;
            if(emptyRestr1 != never()) emptyRestrOptions += emptyRestr1;
            if(emptyRestr2 != never()) emptyRestrOptions += emptyRestr2;
        }
        case \multi-iteration(e): {
            <mainE, emptyE, emptyRestrE> = factorOutEmpty(e);
            if(mainE != never()) {
                /*
                    A non-empty option in the language defined by this multi-iteration of e (1+ matches of e)
                    is to make sure that in at least 1 spot of this multi-iteration, a non-empty sequence is matched. 
                    Note that this is not necessarily the first or last match, or else we might miss out on tags of lookahead/behinds of empty-match iterations. Howevever, under the assumption that there's at least some non-empty match, we can say that before the first non-empty match, there have only been empty matches. Any empty matches without constraints won't affect anything, hence we only have to consider that there may be a number of constraint matches before the first match.
                 */
                nonEmptyExpr = concatenation(
                    mainE, 
                    alternation(empty(), \multi-iteration(e))
                );
                if(emptyRestrE != never())
                    nonEmptyExpr = concatenation(
                        alternation(empty(), \multi-iteration(emptyRestrE)),
                        nonEmptyExpr
                    );
                nonEmptyOptions += nonEmptyExpr;
            }
            if(emptyE != never()) isEmpty = true;
            else if(emptyRestrE != never()) 
                /*
                    Despite it being an empty match, mutliple concatenations may still be different than a single one since each can add tags to from within a lookaround. Hence we can't simulate this without using multi-iteration here too.
                */
                emptyRestrOptions += \multi-iteration(emptyRestrE);
        }
        case lookahead(e1, e2): {
            <main1, empty1, emptyRestr1> = factorOutEmpty(e1);
            <main2, empty2, emptyRestr2> = factorOutEmpty(e2);

            Maybe[Regex] laM = nothing();
            if(empty2 != never())             laM = nothing(); 
            else if(main2 != never()){
                if(emptyRestr2 != never())    laM = just(alternation(main2, emptyRestr2));
                else                          laM = just(main2);
            } else if(emptyRestr2 != never()) laM = just(emptyRestr2);

            if(main1 != never()) {
                if(just(la) := laM)   nonEmptyOptions += lookahead(main1, la);
                else                  nonEmptyOptions += main1;
            }
            if(empty1 != never()) {
                if(just(la) := laM)   emptyRestrOptions += lookahead(empty1, la);
                else                  isEmpty = true;
            } 
            if(emptyRestr1 != never()) {
                if(just(la) := laM)   emptyRestrOptions += lookahead(emptyRestr1, la);
                else                  emptyRestrOptions += emptyRestr1;
            }
        }
        case lookbehind(e1, e2): {
            <main1, empty1, emptyRestr1> = factorOutEmpty(e1);
            <main2, empty2, emptyRestr2> = factorOutEmpty(e2);

            Maybe[Regex] lbM = nothing();
            if(empty2 != never())             lbM = nothing(); 
            else if(main2 != never()){
                if(emptyRestr2 != never())    lbM = just(alternation(main2, emptyRestr2));
                else                          lbM = just(main2);
            } else if(emptyRestr2 != never()) lbM = just(emptyRestr2);

            if(main1 != never()) {
                if(just(lb) := lbM)   nonEmptyOptions += lookbehind(main1, lb);
                else                  nonEmptyOptions += main1;
            }
            if(empty1 != never()) {
                if(just(lb) := lbM)   emptyRestrOptions += lookbehind(empty(), lb);
                else                  isEmpty = true;
            } 
            if(emptyRestr1 != never()) {
                if(just(lb) := lbM)   emptyRestrOptions += lookbehind(emptyRestr1, lb);
                else                  emptyRestrOptions += emptyRestr1;
            }
        }
        case \negative-lookahead(e1, e2): {
            <main1, empty1, emptyRestr1> = factorOutEmpty(e1);
            <main2, empty2, emptyRestr2> = factorOutEmpty(e2);

            if(empty2 != never()) // It's always possible to match the empty string, hence a negative lookahead of an empty string is impossible to match
                return <never(), never(), never()>;

            Regex la = never();
            if(main2 != never()){
                if(emptyRestr2 != never())    la = alternation(main2, emptyRestr2);
                else                          la = main2;
            } else if(emptyRestr2 != never()) la = emptyRestr2;

            if(main1 != never())
                nonEmptyOptions += \negative-lookahead(main1, la);

            if(empty1 != never()) {
                if (la != never()) emptyRestrOptions += \negative-lookahead(empty(), la);
                else isEmpty = true;
            } 
            if(emptyRestr1 != never()) {
                if(la != never())     emptyRestrOptions += \negative-lookahead(emptyRestr1, la);
                else                  emptyRestrOptions += emptyRestr1;
            }
        }
        case \negative-lookbehind(e1, e2): {
            <main1, empty1, emptyRestr1> = factorOutEmpty(e1);
            <main2, empty2, emptyRestr2> = factorOutEmpty(e2);

            if(empty2 != never()) // It's always possible to match the empty string, hence a negative lookbehind of an empty string is impossible to match
                return <never(), never(), never()>;

            Regex lb = never();
            if(main2 != never()){
                if(emptyRestr2 != never())    lb = alternation(main2, emptyRestr2);
                else                          lb = main2;
            } else if(emptyRestr2 != never()) lb = emptyRestr2;

            if(main1 != never())
                nonEmptyOptions += \negative-lookbehind(main1, lb);

            if(empty1 != never()) {
                if(lb != never())     emptyRestrOptions += \negative-lookahead(empty(), lb);
                else                  isEmpty = true;
            } 
            if(emptyRestr1 != never()) {
                if(lb != never())     emptyRestrOptions += \negative-lookahead(emptyRestr1, lb);
                else                  emptyRestrOptions += emptyRestr1;
            }
        }
        case subtract(e1, e2): {
            <main1, empty1, emptyRestr1> = factorOutEmpty(e1);
            <main2, empty2, emptyRestr2> = factorOutEmpty(e2);

            list[Regex] subtractParts = [];
            if(main2 != never())       subtractParts += main2;
            if(empty2 != never())      subtractParts += empty2;
            if(emptyRestr2 != never()) subtractParts += emptyRestr2;
            Regex subtraction = reduceAlternation(Regex::alternation(subtractParts));

            if(main1 != never()) {
                if(subtraction != never()) nonEmptyOptions += subtract(main1, subtraction);
                else                       nonEmptyOptions += main1;
            }
            if(empty1 != never()) {
                if(subtraction != never()) emptyRestrOptions += subtract(empty(), subtraction);
                else                       isEmpty = true;
            } 
            if(emptyRestr1 != never()) { 
                if(subtraction != never()) emptyRestrOptions += subtract(emptyRestr1, subtraction);
                else                       emptyRestrOptions += emptyRestr1;
            }
        }
        case mark(tags, e): {
            <mainE, emptyE, emptyRestrE> = factorOutEmpty(e);
            if(mainE != never())       nonEmptyOptions += mark(tags, mainE);
            if(emptyE != never())      isEmpty = true;
            if(emptyRestrE != never()) emptyRestrOptions += emptyRestrE;
        }
    }

    // If the input doesn't accept empty strings at all, use the original expression as the non-empty result, as this expressions is most likely less complex than the constructed one
    if(
        size(nonEmptyOptions)>0 
        && !isEmpty 
        && size(emptyRestrOptions)==0
    ) 
        return <r, never(), never()>;

    return <
        size(nonEmptyOptions)>0 
            ? getCachedRegex(reduceAlternation(Regex::alternation(nonEmptyOptions))) 
            : never(),
        isEmpty 
            ? getCachedRegex(empty()) 
            : never(),        
        size(emptyRestrOptions)>0 
            ? getCachedRegex(reduceAlternation(Regex::alternation(emptyRestrOptions)))
            : never()
    >;
}
