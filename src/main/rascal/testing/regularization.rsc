module testing::regularization

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
import ParseTree;
import IO;

syntax A = @category="test" 'a'*;


void main() {
    resetFile();

    Grammar gr = grammar(#A);
    addToFile(gr);

    gr = expandParameterizedSymbols(gr);
    addToFile(gr);

    gr = makeRegularStubs(gr);
    addToFile(gr);

    gr = addHoles(gr);
    addToFile(gr);
    
    gr = literals(gr);
    addToFile(gr);

    gr = expandRegularSymbols(gr);
    addToFile(gr);
}

loc pos = |project://syntax-highlighter/testOutput.txt|;
void resetFile() = writeFile(pos, "");
void addToFile(value text) = writeFile(pos, readFile(pos)+"<text>\n\n");