module transformations::normalize

import lang::rascal::grammar::definition::Parameters;
import lang::rascal::grammar::definition::Regular;
import lang::rascal::grammar::definition::Productions;
import lang::rascal::grammar::definition::Modules;
import lang::rascal::grammar::definition::Priorities;
import lang::rascal::grammar::definition::Literals;
import lang::rascal::grammar::definition::Symbols;
import lang::rascal::grammar::definition::Keywords;
import lang::rascal::grammar::ConcreteSyntax;

import Grammar;

Grammar normalize(Grammar gr) {
    gr = expandParameterizedSymbols(gr);
    gr = makeRegularStubs(gr);
    gr = literals(gr);
    gr = expandRegularSymbols(gr);
    return gr;
}
