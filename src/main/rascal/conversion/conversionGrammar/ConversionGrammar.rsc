module conversion::conversionGrammar::ConversionGrammar
extend ParseTree;

import lang::rascal::grammar::definition::Regular;

import regex::Regex;
import Scope;

data ConversionGrammar = convGrammar(Symbol \start, rel[Symbol, ConvProd] productions);
alias ProdMap = map[Symbol, set[ConvProd]];

@doc {
    The base production rule data for a conversion grammar:
    - symb: The identifier of the production, a non-terminal symbol
    - parts: The right handside of the production, consisting of non-terminals and terminal regular expressions
}
data ConvProd = convProd(Symbol symb, list[ConvSymbol] parts);
data ConvSymbol = symb(Symbol ref, ScopeList scopes, set[Production] source) // Non-terminal, with the scopes to assign it
                | delete(ConvSymbol from, ConvSymbol del)                    // Deleting one non-terminal from another non-terminal
                | follow(ConvSymbol sym, ConvSymbol follow)                  // Matching sym only if followed by follow
                | notFollow(ConvSymbol sym, ConvSymbol follow)               // Matching sym only if not followed by follow
                | precede(ConvSymbol sym, ConvSymbol precede)                // Matching sym only if preceded by precede
                | notPrecede(ConvSymbol sym, ConvSymbol precede)             // Matching sym only if not preceded by precede
                | atEndOfLine(ConvSymbol sym)                                // Matching sym only if it's at the end of the line
                | atStartOfLine(ConvSymbol sym)                              // Matching sym only if it's at the start of the line
                | regexp(Regex regex);                                       // Terminal
// Note that after regex conversion is performed, all modifiers are gone. Hence only `symb` and `regexp` is left in the grammar.


@doc {
    Removes all production sources from the grammar
}
&T stripSources(&T anything) = visit (anything) {
    case symb(ref, scopes, _) => symb(ref, scopes, {})
    case meta(ref, set[Production] p) => meta(ref, {})
};

@doc {
    Follows any sequence of aliases until a defining symbol in the grammar is reached, and returns said symbol
}
Symbol followAlias(Symbol aliasSym, ConversionGrammar grammar) {
    aliasSym = getWithoutLabel(aliasSym);
    while({convProd(_, [symb(ref, _, _)])} := grammar.productions[aliasSym]) aliasSym = getWithoutLabel(ref);
    return aliasSym;
}