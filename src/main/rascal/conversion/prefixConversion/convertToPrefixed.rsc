module conversion::prefixConversion::convertToPrefixed

import Relation;
import Map;
import IO;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::prefixConversion::findNonProductiveRecursion;
import conversion::util::equality::deduplicateProds;
import conversion::util::equality::deduplicateSymbols;
import conversion::util::equality::getEquivalentSymbols;
import conversion::util::meta::applyScopesAndSources;
import conversion::util::meta::LabelTools;
import conversion::util::meta::wrapRegexScopes;
import conversion::util::transforms::removeUnreachable;
import regex::RegexTypes;
import regex::RegexCache;
import regex::PSNFATools;
import regex::RegexTransformations;
import Logging;
import Warning;
import Scope;

@doc {
    Makes sure every production starts with a regular expression

    The assumption on the input is:
        - The grammar only contains `ref` and `regexp` conversion symbols

    The guarantee on the output grammar is:
        - The language is a broadening of the original language
        - Every production starts with a regular expression
        - Every symbol has an empty production
        - There are no non-productive loops in the grammar where you can recurse without consuming any characters
}
WithWarnings[ConversionGrammar] convertToPrefixed(ConversionGrammar grammar, Logger log) {
    log(Section(), "to prefixed");
    list[Warning] warnings = [];

    ProdMap prods = Relation::index(grammar.productions);

    set[Symbol] rightRecursiveSyms = {};
    ProdMap oldProds;
    do {
        oldProds = prods;
        for(sym <- prods) {
            <newWarnings, symProds, isRightRecursive> = convertToPrefixed(sym, oldProds, sym in rightRecursiveSyms);
            warnings += newWarnings;
            prods[sym] = symProds;
            if(isRightRecursive) rightRecursiveSyms += sym;
            log(ProgressDetailed(), "performed left-symbol substitution for <sym>, which is<isRightRecursive?"":" not"> right recursive");
        }     
        
        log(Progress(), "performed left-symbol substitution iteration");
    } while(oldProds!=prods);

    log(Progress(), "finished left-symbol substitution");

    // Deduplicate the resulting symbols, and remove unreachable symbols
    grammar = deduplicateSymbols(
        convGrammar(grammar.\start, toRel(prods)), 
        Symbol (Symbol a, Symbol b) {
            if(a==grammar.\start) return a;
            return b;
        },
        DedupeType (Symbol sym) {
            return replace();
        },
        defaultSymEquals
    );
    grammar = removeUnreachable(grammar);

    log(Progress(), "deduplicated symbols in grammar");

    return <warnings, grammar>;
}

@doc {
    Performs one iteration of prefix conversion, which might or might not be stable afterwards

    rightRecursive: whether everything should become right recursive, due to presence of a self left-recursive symbol
}
tuple[
    list[Warning] warnings,
    set[ConvProd] newProds,
    bool rightRecursive
] convertToPrefixed(Symbol sym, ProdMap prods, bool rightRecursive) {
    list[Warning] warnings = [];
    set[ConvProd] out = prods[sym] + {convProd(label("empty", sym), [])};


    // Perform some analysis to obtain problematic lookahead regexes
    newProds = prods;
    newProds[sym] = out;
    set[EmptyPath] emptyPaths = findNonProductiveRecursion(sym, newProds);
    set[ConvProd] emptyPathProds = {p | [<p, _>, *_] <- emptyPaths};

    // Remove nullable regexes per production
    for(p:convProd(lDef, parts) <- out) {
        if(parts == []) continue;
        orParts = parts;

        // Remove nullable prefixes, but keep the non-nullable parts independently
        while([regexp(r), *rest] := parts) {
            shouldStrip = alwaysAcceptsEmpty(r) || p in emptyPathProds;
            if(!shouldStrip) break;

            <mainR, emptyR, emptyRestrR> = factorOutEmpty(r);
            if(mainR != never()) 
                out += convProd(lDef, [regexp(mainR), ref(sym, [], {})]);

            parts = rest;
        }

        // Expand left most symbol
        if([cs:ref(refSym, scopes, sources), *rest] := parts) {
            // Handle direct left self-recursion
            if(getWithoutLabel(refSym) == sym) {
                if(scopes != []) warnings += inapplicableScope(cs, p);

                // If some `x` can follow a self-reference, all of the production must be right-recursive to allow `x` to come after any alternative
                if(!rightRecursive && rest != []) {
                    rightRecursive = true;
                    stable = false;
                }
            } 
            // Handle left reference to another symbol
            else {
                <expandedProds, rightRecursive> = getExpandedProds(getWithoutLabel(refSym), scopes, sources, sym, prods);
                out += expandedProds;
            }
            
            parts = rest;
        }

        // Ensure the production is right-recursive, if necessary
        if(rightRecursive) {
            if(parts!=[] && [*_, ref(sym, [], _)] !:= parts) 
                parts = parts + ref(sym, [], {});
        }

        // Replace the old part by the remainder
        if(parts != orParts) {
            out -= {p};
            if(parts != []) 
                out += convProd(lDef, parts);
        }
    }

    out = deduplicateProds(out);
    return <warnings, out, rightRecursive>;
}

@doc {
    Retrieves the productions of the given symbol, while applying the given scopes and sources to every symbol of every production, and suffixing every production by the given continuation symbol.
}
tuple[
    set[ConvProd] prods,
    bool rightRecursive
 ] getExpandedProds(Symbol sym, ScopeList scopes, set[SourceProd] sources, Symbol target, ProdMap prods) {
    symProds = prods[sym];

    set[ConvProd] out = {};
    bool rightRecursive = false;
    for(convProd(lSym, parts) <- symProds) {
        newParts = [applyScopesAndSources(p, scopes, sources) | p <- parts];
        if(
            [*firstParts, ref(refSym, [], so)] := newParts, 
            getWithoutLabel(refSym) in {sym, target}
        ) {
            newParts = [*firstParts, ref(copyLabel(refSym, target), [], so)];
            rightRecursive = true; // We now need `target` to always be able to reproduce the behavior of 2 instances of itself
        } else {
            newParts += ref(target, [], {});
        }
        out += convProd(copyLabel(lSym, target), newParts);
    }
    return <out, rightRecursive>;
}
