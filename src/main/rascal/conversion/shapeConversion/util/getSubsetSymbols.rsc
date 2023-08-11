module conversion::shapeConversion::util::getSubsetSymbols

import Relation;
import Set;
import IO;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;
import regex::PSNFATools;
import Scope;

@doc {
    Retrieves a subset relation between non-terminal symbols. Such that if A is a subset of B, the language of A is a subset of the language of B (note that it's not if and only if, we might not detect all proper subsets). This subset process considers language containment of different regular expressions and non-terminals. 
    If rightRecursive is set to true, we assume all symbols in the grammar are right recursive and nullable so we consider this subset relation modulo consecutive symbol containment (subset) too (E.g. if B is a subset of C: `A -> B C` = `A -> C`). And note that we believe that `mcsc(A) ⊆ B => L(A) ⊆ L(B)` where `mcsc(A)` be a non-terminal with all productions of `A` modulo consecutive symbol containment (this isn't trivial and would has to be proven). `mcsc(A) ⊆ mcsc(B) =/> L(A) ⊆ L(B)` 

    This is based on relation refinement. 
}
rel[Symbol, Symbol] getSubsetSymbols(ConversionGrammar grammar)
    = getSubsetSymbols(grammar, true);
rel[Symbol, Symbol] getSubsetSymbols(ConversionGrammar grammar, bool rightRecursive) {
    symbols = grammar.productions<0>;
    rel[Symbol, Symbol] subsets = {<a, b> | a <- symbols, b <- symbols};

    map[Symbol, set[Symbol]] dependents = index({
        <dependency, dependent> 
        | <dependent, convProd(_, parts, _)> <- grammar.productions,
          symb(dependency, _) <- parts});
    map[Symbol, set[ConvProd]] prods = index(grammar.productions);

    set[Symbol] checkSymbols = symbols;
    while(size(checkSymbols) > 0) {
        set[Symbol] newCheckSymbols = {};

        for(e:<a, b> <- subsets) {
            if(!(a in checkSymbols)) continue; // If the lhs of the subset entry is not in the checkSymbols, nothing that might affect previous conclusions has changed
            if(a == b) continue; // Always a subset of itself

            if(isNotSubset(a, b, subsets, prods, rightRecursive)){
                subsets -= e;

                // When the subset relation is removed, only other symbols with productions including this dependency might be affected. 
                if(a in dependents)
                    newCheckSymbols += dependents[a];
            }
        }

        checkSymbols = newCheckSymbols;
    }

    return subsets;
}

bool isNotSubset(Symbol sub, Symbol super, rel[Symbol, Symbol] subsets, map[Symbol, set[ConvProd]] prods, bool rightRecursive) {
    set[ConvProd] subProds = prods[sub];
    set[ConvProd] superProds = prods[super];

    for(prod <- subProds){
        bool hasProd = any(
            superProd <- superProds, 
            prodIsSubset(prod, superProd, subsets, rightRecursive)
        );
        if(!hasProd) {
            return true;
        }
    }

    return false;
}

bool prodIsSubset(convProd(_, subParts, _), convProd(_, superParts, _), rel[Symbol, Symbol] subsets, bool rightRecursive) {
    subSize = size(subParts);
    superSize = size(superParts);
    superI = 0;
    for(subI <- [0..subSize]) {
        pSub = subParts[subI];
        if(superI >= superSize) return false;
        pSuper = superParts[superI];

        if(regexp(rSub) := pSub) {
            if(regexp(_) !:= pSuper && !rightRecursive) return false;
            while(regexp(_) !:= pSuper){
                superI += 1;
                if(superI >= superSize) return false;
                pSuper = superParts[superI];
            }

            if(regexp(rSuper) := pSuper) {
                if(!isSubset(rSub, rSuper)) return false;
            } 
            superI += 1;
        } else if(symb(symSub, scopesSub) := pSub) {
            if(rightRecursive) {
                bool matches = false;
                while(!matches, symb(symSuper, scopesSuper) := pSuper) {
                    matches = scopesSub == scopesSuper 
                            && <getWithoutLabel(symSub), getWithoutLabel(symSuper)> in subsets;
                    if(!matches) {
                        superI += 1;
                        if(superI >= superSize) return false;
                        pSuper = superParts[superI];
                    }
                }
                if(!matches) return false;
            } else {
                if(symb(symSuper, scopesSuper) := pSuper) {
                    if(scopesSub != scopesSuper) return false;
                    if(<
                        getWithoutLabel(symSub), 
                        getWithoutLabel(symSuper)
                        > notin subsets) return false;
                } else 
                    return false;
                superI += 1;
            }
        } else 
            throw "Unexpected symbol, only non-terminals and regular expressions are allowed, found: <pSub>";
    }

    while(superI < superSize) {
        pSuper = superParts[superI];
        if(regexp(r) := pSuper) {
            if(!acceptsEmpty(r)) return false;
        } else if(symb(symSuper, _) := pSuper) {
            if(!rightRecursive) return false;
        }
        superI += 1;        
    }

    return true;
}

// list[ConvSymbol] mergeSubsetEqual(list[ConvSymbol] parts, rel[Symbol, Symbol] subsets) {
//     Maybe[tuple[Symbol, Scopes]] prevSuper = nothing();
//     list[ConvSymbol] newParts = [];

//     void flush() {
//         if(just(<sym, scopes>) := prevSuper) 
//             newParts += symb(sym, scopes);
//         prevSuper = nothing();
//     }
//     for(part <- parts) {
//         if(symb(ref, scopes) := part) {
//             if(just(<super, scopes>) := prevSuper) {
//                 if(<ref, super> in subsets)
//                     prevSuper = just(<super, scopes>);
//                 else if(<super, ref> in subsets)
//                     prevSuper = just(<ref, scopes>);
//                 else {
//                     flush();
//                     prevSuper = just(<ref, scopes>);
//                 }
//             } else 
//                 prevSuper = just(<ref, scopes>);
//         } else {
//             flush();
//             newParts += part;
//         }
//     }
//     flush();

//     return newParts;
// }