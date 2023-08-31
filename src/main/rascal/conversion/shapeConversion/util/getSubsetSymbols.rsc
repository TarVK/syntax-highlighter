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
    map[Symbol, set[ConvProd]] prods = index(grammar.productions);

    // Note that in all calculations we exclude the self-subset checks, since these are inherently met.

    // Collect all dependency constraints, such that for an any entry `<a, b>`, we know `L(a)` is a subset of `L(b)` if the constraint is met
    symbols = grammar.productions<0>;
    SubtractCache cache = ();
    map[tuple[Symbol, Symbol], DependencyConstraints] constraints = ();
    for(a <- symbols, b <- symbols, a != b) {
        <cache, constrM> = getSubsetDependencies(a, b, prods, rightRecursive, cache);
        if(just(constr) := constrM)
            constraints[<a, b>] = simplify(constr);
    }

    // Initialize the possible subsets based on the initial constraints
    rel[Symbol, Symbol] subsets = {
        <a, b> 
        | a <- symbols, b <- symbols,
        <a, b> in constraints || a == b
    };

    // Keep track of the subset relations that might need updating
    rel[Symbol, Symbol] checks = subsets - {<a, a> | a <- symbols};
    map[tuple[Symbol, Symbol], set[tuple[Symbol, Symbol]]] allDependencies = (
        <a, b>: {}
        | a <- symbols, b <- symbols
    );
    map[tuple[Symbol, Symbol], set[tuple[Symbol, Symbol]]] allDependents = (
        <a, b>: {}
        | a <- symbols, b <- symbols
    );

    // Keep removing elements from the subsets until stable
    while(size(checks)>0) {
        set[tuple[Symbol, Symbol]] newChecks = {};
        for(subset <- checks) {
            // Checks if the constraints are still met
            if(just(dependencies) := getConstraintDependencies(constraints[subset], subsets)) {
                // If the constraints are still met, update the dependencies
                oldDependencies = allDependencies[subset];
                if(oldDependencies == dependencies) continue;

                allDependencies[subset] = dependencies;
                for(dependency <- oldDependencies) allDependents[dependency] -= subset;
                for(dependency <- dependencies) allDependents[dependency] += subset;
            } else {
                // If the constraints are no longer met, we remove it from the subset and check the possibly affected subset
                subsets -= {subset};
                newChecks += allDependents[subset];
                oldDependencies = allDependencies[subset];
                for(dependency <- oldDependencies) allDependents[dependency] -= subset;
            }
        }

        checks = newChecks;
    }

    return subsets;
}


@doc {
    Retrieves what subset dependencies are required for symbol `sub` to define a language that's a subset of the language of symbol `super`. If nothing is returned, `sub` can never be a subset of `super`
}
tuple[SubtractCache, Maybe[DependencyConstraints]] getSubsetDependencies(
    Symbol sub, 
    Symbol super, 
    map[Symbol, set[ConvProd]] prods, 
    bool rightRecursive,
    SubtractCache cache
) {
    set[ConvProd] subProds = prods[sub];
    set[ConvProd] superProds = prods[super];

    // Handle aliases
    if({convProd(_, [symb(subRef, _)], _)} := subProds)
        return <cache, just(subset(subRef, super))>;
    if({convProd(_, [symb(superRef, _)], _)} := superProds)
        return <cache, just(subset(sub, superRef))>;

    // Handle normal symbols
    set[DependencyConstraints] requirements = {};
    for(prod <- subProds){
        set[DependencyConstraints] options = {};
        for(superProd <- superProds) {
            <cache, constraintsM> = getSubprodDependencies(prod, superProd, rightRecursive, cache);
            if(just(constraints) := constraintsM)
                options += constraints;
        }

        if(size(options)==0) return <cache, nothing()>;

        requirements += disjunction(options);
    }

    return <cache, just(conjunction(requirements))>;
}

tuple[SubtractCache, Maybe[DependencyConstraints]] getSubprodDependencies(
    convProd(_, subParts, _), 
    convProd(_, superParts, _), 
    bool rightRecursive,
    SubtractCache cache
) {
    set[DependencyConstraints] constraints = {};

    list[tuple[Regex, Regex]] regexConstraints = [];

    subSize = size(subParts);
    superSize = size(superParts);
    superI = 0;
    subI = 0;
    while(subI < subSize) {
        pSub = subParts[subI];
        if(superI >= superSize) return <cache, nothing()>;
        pSuper = superParts[superI];

        if(regexp(rSub) := pSub) {
            if(regexp(rSuper) := pSuper) {
                regexConstraints += <rSub, rSuper>;
            } else 
                return <cache, nothing()>;
            superI += 1;
        } else if(symb(symSub, scopesSub) := pSub) {
            if(rightRecursive) {
                bool matches = false;

                list[tuple[Symbol, Scopes]] superSymbolSeq = [];
                while(symb(symSuper, scopesSuper) := pSuper) {
                    superSymbolSeq += <symSuper, scopesSuper>;
                    superI += 1;
                    if(superI >= superSize) break;
                    pSuper = superParts[superI];
                }
                if(size(superSymbolSeq)==0) return <cache, nothing()>;

                list[tuple[Symbol, Scopes]] subSymbolSeq = [<symSub, scopesSub>];
                while(subI+1 < subSize && symb(nSymSub, nScopesSub) := subParts[subI+1]) {
                    subSymbolSeq += <nSymSub, nScopesSub>;
                    subI += 1;
                }

                DependencyConstraints getConstraint(
                    list[tuple[Symbol, Scopes]] subSymbolSeq, 
                    list[tuple[Symbol, Scopes]] superSymbolSeq
                ) {
                    if([] == subSymbolSeq) return trueConstr();
                    if([] == superSymbolSeq) return falseConstr();

                    if(
                        [<subFirst, subFirstScopes>, *subSymbolSeqRest] := subSymbolSeq,
                        [<superFirst, superFirstScopes>, *superSymbolSeqRest] := superSymbolSeq
                    ) {
                        if(subFirstScopes == superFirstScopes)
                            return disjunction({
                                conjunction({
                                    subset(
                                        getWithoutLabel(subFirst), 
                                        getWithoutLabel(superFirst)
                                    ), 
                                    getConstraint(subSymbolSeqRest, superSymbolSeq)
                                }),
                                getConstraint(subSymbolSeq, superSymbolSeqRest)
                            });
                        else
                            return getConstraint(subSymbolSeq, superSymbolSeqRest);
                    }

                    return falseConstr();
                }

                constraint = getConstraint(subSymbolSeq, superSymbolSeq);
                if(constraint == falseConstr()) return <cache, nothing()>;
                constraints += constraint;
            } else {
                if(symb(symSuper, scopesSuper) := pSuper) {
                    if(scopesSub != scopesSuper) return <cache, nothing()>;
                    constraints += subset(
                        getWithoutLabel(symSub), 
                        getWithoutLabel(symSuper)
                    );
                } else 
                    return <cache, nothing()>;
                superI += 1;
            }
        } else 
            throw "Unexpected symbol, only non-terminals and regular expressions are allowed, found: <pSub>";

        subI += 1;
    }

    // Check remainders of the super production
    while(superI < superSize) {
        pSuper = superParts[superI];
        if(regexp(r) := pSuper) {
            if(!acceptsEmpty(r)) return <cache, nothing()>;
        } else if(symb(symSuper, _) := pSuper) {
            if(!rightRecursive) return <cache, nothing()>;
        }
        superI += 1;        
    }

    // Check the regular expressions only if all other constraints are possible to be met (regex processing can be heavy)
    for(<rSub, rSuper> <- regexConstraints){
        <cache, s> = isSubset(rSub, rSuper, cache);
        if(!s) return <cache, nothing()>;
    }

    return <cache, just(conjunction(constraints))>;
}

@doc {
    Checks whether the constraints are met by the given subset relationship,
    and if so, returns all the subbsets that were used for this.
}
Maybe[rel[Symbol, Symbol]] getConstraintDependencies(DependencyConstraints constraints, rel[Symbol, Symbol] subsets) {
    switch(constraints) {
        case subset(a, b): return <a, b> in subsets ? just({<a, b>}) : nothing();
        case conjunction(conConstraints): {
            rel[Symbol, Symbol] dependencies = {};
            for(constraint <- conConstraints) {
                if(just(newDependencies) := getConstraintDependencies(constraint, subsets))
                    dependencies += newDependencies;
                else
                    return nothing();
            }
            return just(dependencies);
        }
        case disjunction(disConstraints): {
            for(constraint <- disConstraints) {
                if(just(dependencies) := getConstraintDependencies(constraint, subsets))
                    return just(dependencies);
            }
            return nothing();
        }
        case trueConstr(): return just({});
        case falseConstr(): return nothing();
    }
    return nothing();
}

data DependencyConstraints 
    = subset(Symbol a, Symbol b)
    | conjunction(set[DependencyConstraints])
    | disjunction(set[DependencyConstraints])
    | trueConstr()
    | falseConstr();

// DependencyConstraints simplify(DependencyConstraints constraints) = constraints;
DependencyConstraints simplify(DependencyConstraints constraints) = visit(constraints) {
    case subset(a, a) => trueConstr()
    case conjunction(terms): {
        set[DependencyConstraints] newTerms = {};
        for(term <- terms) {
            if(conjunction(subTerms) := term) newTerms += subTerms;
            else if(trueConstr() := term) ;
            else if(falseConstr() := term) insert falseConstr();
            else newTerms += term;
        }
        if({} := newTerms) insert trueConstr();
        if({term} := newTerms) insert term;
        insert conjunction(newTerms);
    }
    case disjunction(terms): {
        set[DependencyConstraints] newTerms = {};
        for(term <- terms) {
            if(disjunction(subTerms) := term) newTerms += subTerms;
            else if(falseConstr() := term) ;
            else if(trueConstr() := term) insert trueConstr();
            else newTerms += term;
        }
        if({} := newTerms) insert falseConstr();
        if({term} := newTerms) insert term;
        insert disjunction(newTerms);
    }
};

// Utility method that can be used by other code
@doc {
    Checks wheter the first production's language is a subset of the seconds' knowing the given subset relationship. If true is returned, this guarantees one is a subset of the other, if false is returned it's unknown. 
}
bool prodIsSubset(ConvProd sub, ConvProd super, rel[Symbol, Symbol] subsets, bool rightRecursive) {
    if(<_, just(constraints)> := getSubprodDependencies(sub, super, rightRecursive, ())) {
        if(just(_) := getConstraintDependencies(constraints, subsets))
            return true;
    }
    return false;
}

tuple[SubtractCache, bool] prodIsSubset(ConvProd sub, ConvProd super, rel[Symbol, Symbol] subsets, bool rightRecursive, SubtractCache cache) {
    <cache, res> = getSubprodDependencies(sub, super, rightRecursive, cache);

    if(
        just(constraints) := res,
        just(_) := getConstraintDependencies(constraints, subsets)
    )
        return <cache, true>;

    return <cache, false>;
}