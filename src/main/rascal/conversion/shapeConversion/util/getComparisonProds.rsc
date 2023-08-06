module conversion::shapeConversion::util::getComparisonProds

import ParseTree;
import IO;

import conversion::conversionGrammar::ConversionGrammar;

// A symbol used to represent a self-reference, regardless of what that symbol is
data Symbol = self();

@doc {
    Obtains productions that can be used for equivalence or subset testing, by getting rid of non-CFG-structure related data. The productions are assumed to all be right-recursive (or empty). 
    The "selfSet" represents the set of symbols that would be considered part of self, such that consecutive occurences are squashed.
}
set[ConvProd] getComparisonProds(set[ConvProd] prods, set[Symbol] selfSet) {
    set[ConvProd] out = {};

    for(convProd(lDef, parts, _) <- prods) {
        newParts = combineConsecutive(replaceSymbols(parts, selfSet, self(), false));
        out += convProd(self(), newParts, {});
    }

    return out;
}


@doc {
    Obtains productions that can be used for equivalence or subset testing, by getting rid of non-CFG-structure related data. The productions are assumed to all be right-recursive (or empty). 
    The "selfSet" represents the set of symbols that would be considered part of self, such that consecutive occurences are squashed.
}
tuple[set[ConvProd], rel[ConvProd, ConvSymbol, ConvSymbol]] getComparisonProdsIgnoreScopes(set[ConvProd] prods, set[Symbol] selfSet) {
    set[ConvProd] out = {};
    rel[ConvProd, rel[ConvSymbol, ConvSymbol]] problems = {};

    for(p:convProd(lDef, parts, _) <- prods) {
        <newParts, conflicts> = combineConsecutiveIgnoreScopes(replaceSymbols(parts, selfSet, self(), false));
        problems += {<p, a, b> | <a, b> <- conflicts};
        out += convProd(self(), newParts, {});
    }

    return <out, problems>;
}

@doc {
    Replaces symbols occuring in "replace" by "replaceBy" in the "parts" list. 
}
list[ConvSymbol] replaceSymbols(list[ConvSymbol] parts, set[Symbol] replace, Symbol replaceBy, bool keepLabel) 
    = [
        symb(sym, scopes) := part
            ? getWithoutLabel(sym) in replace 
                ? symb(keepLabel ? copyLabel(sym, replaceBy) : replaceBy, scopes)
                : part
            : part
        | part <- parts
    ];


@doc {
    Combines multiple consecutive symbols if they are equivalent
}
list[ConvSymbol] combineConsecutive(list[ConvSymbol] parts) = visit(parts) {
    case [*p, symb(ref, scopes), symb(ref, scopes), *s] => 
        combineConsecutive([*p, symb(ref, scopes), *s])
};


@doc {
    Combines multiple consecutive symbols if they are equivalent except for the scopes. Also returns the set of incompatible scopes if encountered.
}
tuple[list[ConvSymbol], rel[ConvSymbol, ConvSymbol]] combineConsecutiveIgnoreScopes(list[ConvSymbol] parts) {
    if([*p, a:symb(ref, scopes), b:symb(ref, scopes2), *s] := parts) {
        <parts, problems> = combineSymbolsIgnoreScopes([*p, symb(ref, scopes), *s]);
        if(scopes != scopes2)
            problems += <a, b>;
        return <parts, problems>;
    }

    return <parts, {}>;
}