module conversion::shapeConversion::util::getEquivalentSymbols

import Relation;
import Set;
import IO;
import util::Maybe;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::util::RegexCache;
import regex::PSNFATools;
import Scope;

@doc {
    Retrieves all symbols that are equivalent modulo regex structure and symbol names (I.e. different regular expressions that specify the same thing are considered equivalent, as well as different symbol names that specify the same structure).
    If rightRecursive is set to true, we assume all symbols in the grammar are right recursive and nullable so we consider equivalence modulo consecutive equivalent symbol reptition too (E.g. `A -> B B` = `A -> B`)

    This is based on equivalence set partition refinement.
}
set[set[Symbol]] getEquivalentSymbols(ConversionGrammar grammar)
    = getEquivalentSymbols(grammar, true);
set[set[Symbol]] getEquivalentSymbols(ConversionGrammar grammar, bool rightRecursive) {
    symbols = grammar.productions<0>;
    set[set[Symbol]] classes = {symbols};
    ClassMap classMap = (symbol: symbols | symbol <- symbols);

    map[Symbol, set[ConvProd]] prods = index(grammar.productions);

    rel[
        Symbol to, 
        Symbol from
    ] aliases = {
        <aliasFor, sym> 
        | sym <- symbols, 
        {convProd(_, [symb(aliasFor, _)], _)} := prods[sym]
    };

    // map[Symbol, set[Symbol]] dependencies = Relation::index({
    //     <sym, dep>
    //     | <sym, convProd(_, parts, _)> <- grammar/productions,
    //     symb(dep, _) <- parts
    // });
    rel[Symbol, Symbol] dependents = {
        <dep, sym>
        | <sym, convProd(_, parts, _)> <- grammar.productions,
        symb(dep, _) <- parts
    };

    set[set[Symbol]] queue = classes;

    bool stable = false;
    while(!stable) {
        stable = true;
        classLoop: while({class, *rest} := queue) {
            queue = rest;
            if(size(class) <= 1) continue classLoop;

            splitters = {
                splitter
                | sym <- class - aliases<1>,
                convProd(_, splitter, _) <- prods[sym]
            };
            for(splitter <- splitters) {
                <contains, notContains> = split(class, splitter, prods, classMap, rightRecursive);
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

    return classes;
}

alias ClassMap = map[Symbol, set[Symbol]];
map[Symbol, set[Symbol]] getClassMap(set[set[Symbol]] classes) {
    ClassMap classMap = ();
    for(class <- classes) 
        for(sym <- class) 
            classMap[sym] = class;
    return classMap;
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

tuple[
    set[Symbol] contains,
    set[Symbol] notContains
] split(
    set[Symbol] symbols,  
    list[ConvSymbol] splitter, 
    map[Symbol, set[ConvProd]] prods,
    ClassMap classMap,
    bool rightRecursive
) {
    set[Symbol] contains = {};
    set[Symbol] notContains = {};

    for(sym <- symbols) {
        bool doesContain = false;
        for(convProd(_, parts, _) <- prods[sym]) {
            if(prodsEqual(parts, splitter, classMap, rightRecursive)) {
                doesContain = true;
                break;
            }
        }
        
        if(doesContain) contains += sym;
        else            notContains += sym;
    }

    return <contains, notContains>;
}

bool prodsEqual(convProd(_, aParts, _), convProd(_, bParts, _), ClassMap classMap, bool rightRecursive)
    = prodsEqual(aParts, bParts, classMap, rightRecursive);
bool prodsEqual(list[ConvSymbol] aParts, list[ConvSymbol]  bParts, ClassMap classMap, bool rightRecursive) {
    if(rightRecursive) {
        aParts = mergeEqual(aParts, classMap);
        bParts = mergeEqual(bParts, classMap);
    }

    aSize = size(aParts);
    bSize = size(bParts);
    if(aSize != bSize) return false;

    set[tuple[Regex, Regex]] regexChecks = {};
    for(i <- [0..aSize]) {
        pa = aParts[i];
        pb = bParts[i];

        if(regexp(ra) := pa) {
            if(regexp(rb) := pb) {
                // Store regex to check instead of checking immediately, because these checks are somewhat expensive and not always needed if the structure isn't the same
                regexChecks += <ra, rb>;
            } else 
                return false;
        } else if(symb(symA, scopesA) := pa) {
            if(symb(symB, scopesB) := pb) {
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

    for(<ra, rb> <- regexChecks)
        if(!equals(ra, rb)) return false;

    return true;
}

list[ConvSymbol] mergeEqual(list[ConvSymbol] parts, ClassMap classMap) {
    Maybe[tuple[set[Symbol], Scopes]] prevClass = nothing();
    list[ConvSymbol] newParts = [];
    for(part <- parts) {
        if(symb(ref, scopes) := part, ref in classMap) {
            class = classMap[ref];
            if(just(<class, scopes>) := prevClass) {
                ; // They are equivalent, we can skip adding the part
            } else {
                prevClass = just(<class, scopes>);
                newParts += part;
            }
        } else {
            prevClass = nothing();
            newParts += part;
        }
    }

    return newParts;
}