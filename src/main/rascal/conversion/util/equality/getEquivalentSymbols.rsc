module conversion::util::equality::getEquivalentSymbols

import Relation;
import Set;
import IO;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::equality::ProdEquivalence;
import conversion::util::meta::LabelTools;
import regex::PSNFATools;
import regex::PSNFATypes;
import regex::RegexCache;
import Scope;

alias CompProdMap = map[Symbol, set[list[ConvSymbol]]];
alias ClassMap = map[Symbol, set[Symbol]];

@doc {
    Retrieves all symbols that are equivalent modulo regex structure and symbol names (I.e. different regular expressions that specify the same thing are considered equivalent, as well as different symbol names that specify the same structure).

    This is based on equivalence set partition refinement.
}
set[set[Symbol]] getEquivalentSymbols(ConversionGrammar grammar)
    = getEquivalentSymbolsAndRightRecursion(grammar)<0>;
tuple[
    set[set[Symbol]] classes,
    set[Symbol] rightRecursive 
 ] getEquivalentSymbolsAndRightRecursion(ConversionGrammar grammar) {

    symbols = grammar.productions<0>;
    map[Symbol, set[ConvProd]] prods = index(grammar.productions);
    CompProdMap compProds = (
        sym: {getEquivalenceSymbols(parts) | convProd(_, parts) <- prods[sym]}
        | sym <- prods
    );

    set[Symbol] rightRecursive = getRightRecursiveSymbols(prods);
    rel[
        Symbol to, 
        Symbol from
    ] aliases = {
        <aliasFor, sym> 
        | sym <- symbols, 
        {convProd(_, [ref(aliasFor, _, _)])} := prods[sym]
    };

    set[set[Symbol]] classes = {symbols};
    ClassMap classMap = (symbol: symbols | symbol <- symbols);

    rel[Symbol, Symbol] dependents = {
        <dep, sym>
        | <sym, convProd(_, parts)> <- grammar.productions,
        ref(dep, _, _) <- parts
    };

    set[set[Symbol]] queue = classes;

    bool stable = false;
    while(!stable) {
        stable = true;
        classLoop: while({class, *rest} := queue) {
            queue = rest;
            if(size(class) <= 1) continue classLoop;

            splitters = {
                mergeParts 
                | sym <- class - aliases<1>, 
                parts <- compProds[sym], 
                mergeParts := mergeEqual(parts, classMap, rightRecursive)
            };
            for(splitter <- splitters) {
                <contains, notContains> = split(class, splitter, compProds, classMap, rightRecursive);
                <contains, notContains> = followAliases(contains, notContains, aliases);

                if(size(notContains)>0){
                    classes = classes - {class} + {contains, notContains};
                    for(c <- contains) classMap[c] = contains;
                    for(c <- notContains) classMap[c] = notContains;

                    /*
                        We need to check the newly created classes to see whether further splits are possible,
                        And for any classes that contain symbols that depent on elemens of the newly split class, we also need to check if they are still stable
                    */
                    queue += {contains, notContains};
                    for(dependent <- dependents[class])
                        queue += {classMap[dependent]};

                    stable = false;
                    continue classLoop;
                }
            }
        }
    }

    return <classes, rightRecursive>;
}

@doc {
    Splits a set of symbols into the symbols that contain the given splitter production, and those that do not contain it

    RightRecursive is a set of symbols for which we can assume they can match 1 or more times, such that consecutive equivalent symbols can be merged
}
tuple[
    set[Symbol] contains,
    set[Symbol] notContains
] split(
    set[Symbol] symbols,  
    list[ConvSymbol] splitter, 
    CompProdMap compProds,
    ClassMap classMap,
    set[Symbol] rightRecursive
) {
    set[Symbol] contains = {};
    set[Symbol] notContains = {};

    for(sym <- symbols) {
        bool doesContain = false;
        for(parts <- compProds[sym]) {
            parts = mergeEqual(parts, classMap, rightRecursive);

            if(prodsEqual(parts, splitter, classMap)) {
                doesContain = true;
                break;
            }
        }
        
        if(doesContain) contains += sym;
        else            notContains += sym;
    }

    return <contains, notContains>;
}

@doc {
    Checks whether the given two productions are equivalent under the currently known equivalent symbols
}
bool prodsEqual(list[ConvSymbol] aParts, list[ConvSymbol] bParts, ClassMap classMap) {
    aSize = size(aParts);
    bSize = size(bParts);
    if(aSize != bSize) return false;

    for(i <- [0..aSize]) {
        pa = aParts[i];
        pb = bParts[i];

        if(regexNfa(na) := pa) {
            if(regexNfa(nb) := pb) {
                if (na!=nb) return false;
            } else return false;
        } else if(ref(symA, scopesA, _) := pa) {
            if(ref(symB, scopesB, _) := pb) {
                if(scopesA != scopesB) return false;
                symA = getWithoutLabel(symA);
                symB = getWithoutLabel(symB);
                classA = symA in classMap ? classMap[symA] : {symA};
                classB = symB in classMap ? classMap[symB] : {symB};
                if(classA != classB) return false;
            } else 
                return false;
        }
    }

    return true;
}

@doc {
    Merges consecutive right-recursive symbols that belong to the same equivalence class, increasing the chances that two symbols are detected to be equivalent by removing redudant structural information
}
list[ConvSymbol] mergeEqual(list[ConvSymbol] parts, ClassMap classMap, set[Symbol] rightRecursive) {
    Maybe[tuple[set[Symbol], ScopeList]] prevClass = nothing();
    list[ConvSymbol] newParts = [];
    for(part <- parts) {
        if(ref(ref, scopes, _) := part, ref in classMap) {
            if(ref in rightRecursive) {
                class = classMap[ref];
                equal = just(<class, scopes>) := prevClass;
                if(equal) {
                    ; // They are equivalent, we can skip adding the part
                } else {
                    prevClass = just(<class, scopes>);
                    newParts += part;
                }
            } else {
                // If the symbol is not right-recursive, we can't safely merge
                prevClass = nothing();
                newParts += part;
            }
        } else {
            prevClass = nothing();
            newParts += part;
        }
    }

    return newParts;
}

@doc {
    Makes sure that aliases are put in the group that they are an alias for, instead of always appearing in `notContains`
}
tuple[
    set[Symbol] contains,
    set[Symbol] notContains
] followAliases(set[Symbol] contains, set[Symbol] notContains, rel[Symbol to, Symbol from] aliases) {
    set[Symbol] addContain;
    do {
        addContain = aliases[contains] & notContains;
        contains += addContain;
        notContains -= addContain;
    } while(size(addContain)>0);
    return <contains, notContains>;
}

@doc {
    Retrieves all the symbols that are right-recursive
}
set[Symbol] getRightRecursiveSymbols(ProdMap prods) {
    set[Symbol] out = {};
    for(sym <- prods) {
        symProds = prods[sym];
        isRightRecursive = all(
            convProd(_, [*_, last]) <- symProds, 
            ref(s, [], _) := last, 
            getWithoutLabel(s) == sym
        );
        if(isRightRecursive) out += sym;
    }
    return out;
}




// Random functions that might be useful sometime, if it stays commented out, it wasn't useful and can be deleted


// @doc {
//     Converts a class set, into a class map, mapping each symbol to the equivalence class it belongs to
// }
// map[Symbol, set[Symbol]] getClassMap(set[set[Symbol]] classes) {
//     ClassMap classMap = ();
//     for(class <- classes) 
//         for(sym <- class) 
//             classMap[sym] = class;
//     return classMap;
// }

// @doc {
//     Checks whether the two given productions are equivalent, considering the given class map of equivalent symbols

//     If rightRecursive is set to true, it's assumed that all symbols are fully right-recursive
// }
// bool prodsEqual(convProd(_, aParts), convProd(_, bParts), ClassMap classMap, bool rightRecursive) {
//     aParts = getEquivalenceSymbols(aParts);
//     bParts = getEquivalenceSymbols(bParts);
//     if(rightRecursive) {
//         allSymbols = {s | ref(s, _, _) <- aParts+bParts};
//         aParts = mergeEqual(aParts, classMap, allSymbols);
//         bParts = mergeEqual(bParts, classMap, allSymbols);
//     }
//     return prodsEqual(aParts, bParts, classMap, rightRecursive);
// }