module conversion::conversionGrammar::ConversionGrammar

extend ParseTree;

import lang::rascal::grammar::definition::Regular;
import ParseTree;
import Grammar;
import Set;
import Map;
import List;
import String;
import util::Maybe;
import IO;
import lang::rascal::grammar::definition::Characters;

import Visualize;
import conversion::util::RegexCache;
import regex::Regex;
import regex::PSNFATools;
import Scope;
import Warning;

data ConversionGrammar = convGrammar(Symbol \start, rel[Symbol, ConvProd] productions);
alias ProdMap = map[Symbol, set[ConvProd]];

@doc {
    The base production rule data for a conversion grammar:
    - symb: The identifier of the production, a non-terminal symbol
    - parts: The right handside of the production, consisting of non-terminals and terminal regular expressions
    - sources: The production(s) that were used to derive this production from
}
data ConvProd = convProd(Symbol symb, list[ConvSymbol] parts, set[SourceProd] sources);
data SourceProd = convProdSource(ConvProd convProd)
                | origProdSource(Production origProd);
                

data ConvSymbol = symb(Symbol ref, Scopes scopes)                   // Non-terminal, with the scopes to assign it
                | delete(ConvSymbol from, ConvSymbol del)           // Deleting one non-terminal from another non-terminal
                | follow(ConvSymbol sym, ConvSymbol follow)         // Matching sym only if followed by follow
                | notFollow(ConvSymbol sym, ConvSymbol follow)      // Matching sym only if not followed by follow
                | precede(ConvSymbol sym, ConvSymbol precede)       // Matching sym only if preceded by precede
                | notPrecede(ConvSymbol sym, ConvSymbol precede)    // Matching sym only if not preceded by precede
                | atEndOfLine(ConvSymbol sym)                       // Matching sym only if it's at the end of the line
                | atStartOfLine(ConvSymbol sym)                     // Matching sym only if it's at the start of the line
                | regexp(Regex regex);                              // Terminal
// Note that after regex conversion is performed, all modifiers are gone. Hence only `symb` and `regexp` is left in the grammar.




// Allow sources to be specified within an expression, to track how a regular expression was obtained, TODO: 
// data Regex = regexSource(Regex r, set[ConvProd] prods);

// Warnings that may be produced by conversion
data Warning = unsupportedCondition(Condition condition, Production inProd)
             | multipleTokens(set[Scopes] tokens, Production inProd) // Warning because order can not be guaranteed, use a single token declaration instead
             | multipleScopes(set[Scopes] scopes, Production inProd); // Warning because order can not be guaranteed, use a single scope declaration instead

@doc {
    Replaces the given production in the grammar with the new production
}
ConversionGrammar replaceProduction(ConversionGrammar grammar, ConvProd old, ConvProd new) 
    = addProduction(removeProduction(grammar, old), new);

@doc {
    Removes a production from the given grammar
}
ConversionGrammar removeProduction(ConversionGrammar grammar, ConvProd old) {
    grammar.productions = grammar.productions - <old.symb, old>;
    return grammar;
}

@doc {
    Adds a production to the given grammar
}
ConversionGrammar addProduction(ConversionGrammar grammar, ConvProd new) {
    grammar.productions = grammar.productions + <new.symb, new>;
    return grammar;
}



@doc {
    Checks whether two productions define the same language/tokenization from the given index forward
}
bool equalsAfter(a:convProd(_, pa, _), b:convProd(_, pb, _), int index) {
    if(size(pa) != size(pb)) return false;

    for(i <- [index..size(pa)]) {
        sa = pa[i];
        sb = pb[i];
        if(sa == sb) continue;
        if(regexp(ra) := sa && regexp(rb) := sb) 
            if(equals(ra, rb)) continue;

        return false;
    }

    return true;
}

@doc {
    Removes the intermediate conversion production sources from the grammar, and only keeps the base grammar sources
}
&T stripConvSources(&T grammar) = visit (grammar) {
    case set[SourceProd] sources => 
        {s | s:origProdSource(_) <- sources} 
        + {*s | convProdSource(convProd(_, _, s)) <- sources}
};


@doc {
    Removes all production sources from the grammar
}
&T stripSources(&T anything) = visit (anything) {
    case convProd(lDef, parts, _) => convProd(lDef, parts, {})
};

@doc {
    Replaces all occurences of the given symbol in the grammar, and removes its definitions
}
ConversionGrammar replaceSymbol(Symbol replace, Symbol replaceBy, ConversionGrammar grammar) {
    substitutedProductions = { 
        <def, convProd(lDef, [
            symb(sym, scopes) := part 
                ? getWithoutLabel(sym) == replace
                    ? symb(copyLabel(sym, replaceBy), scopes)
                    : part
                : part
            | part <- parts
        ], sources)>
        | <def, convProd(lDef, parts, sources)> <- grammar.productions,
        def != replace // Remove the definition of replace, since it will no longer be referenced
    };
    grammar.productions = substitutedProductions;
    return grammar;
}

@doc {
    Retrieve the raw definition symbol, by getting rid of any potential labels
}
Symbol getWithoutLabel(label(_, sym)) = sym;
default Symbol getWithoutLabel(Symbol sym) = sym;

@doc {
    Keep the label from the first symbol if present, but use the rest of the second symbol
}
Symbol copyLabel(Symbol withLabel, Symbol target) {
    if(label(x, _) := withLabel) return label(x, getWithoutLabel(target));
    return target;
}

@doc {
    Follows any sequence of aliases until a defining symbol in the grammar is reached, and returns said symbol
}
Symbol followAlias(Symbol aliasSym, ConversionGrammar grammar) {
    while({convProd(_, [symb(ref, _)], _)} := grammar.productions[aliasSym]) aliasSym = getWithoutLabel(ref);
    return aliasSym;
}