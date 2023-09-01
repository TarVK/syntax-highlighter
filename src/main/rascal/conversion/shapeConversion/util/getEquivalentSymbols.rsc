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

    bool stable = false;
    while(!stable) {
        stable = true;
        classLoop: for(class <- classes) {
            if(size(class) <= 1) continue classLoop;

            for(sym <- class - aliases<1>) {
                for(prod <- prods[sym]) {
                    <contains, notContains> = split(class, prod, prods, classMap, rightRecursive);
                    <contains, notContains> = followAliases(contains, notContains, aliases);
                    if(size(notContains)>0){
                        classes = classes - {class} + {contains, notContains};
                        for(c <- contains) classMap[c] = contains;
                        for(c <- notContains) classMap[c] = notContains;

                        stable = false;
                        continue classLoop;
                    }
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
    ConvProd splitter, 
    map[Symbol, set[ConvProd]] prods,
    ClassMap classMap,
    bool rightRecursive
) {
    set[Symbol] contains = {};
    set[Symbol] notContains = {};

    for(sym <- symbols) {
        bool doesContain = false;
        for(prod <- prods[sym]) {
            if(prodsEqual(prod, splitter, classMap, rightRecursive)) {
                doesContain = true;
                break;
            }
        }
        if(doesContain) contains += sym;
        else            notContains += sym;
    }

    return <contains, notContains>;
}

bool prodsEqual(convProd(_, aParts, _), convProd(_, bParts, _), ClassMap classMap, bool rightRecursive) {
    if(rightRecursive) {
        aParts = mergeEqual(aParts, classMap);
        bParts = mergeEqual(bParts, classMap);
    }

    aSize = size(aParts);
    bSize = size(bParts);
    if(aSize != bSize) return false;

    for(i <- [0..aSize]) {
        pa = aParts[i];
        pb = bParts[i];

        if(regexp(ra) := pa) {
            if(regexp(rb) := pb) {
                if(!equals(ra, rb)) return false;
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