module testing::normalization

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

// syntax A = @category="test" 'a'*;
// syntax B = @category="test" "" [a-z]*;
syntax B = "a" > "a";


void main() {
    resetFile();

    Grammar gr = grammar(#B);
    addToFile(gr);

    gr = expandParameterizedSymbols(gr);
    addToFile(gr);

    gr = makeRegularStubs(gr);
    addToFile(gr);

    // gr = addHoles(gr);
    // addToFile(gr);
    
    gr = literals(gr);
    addToFile(gr);

    gr = expandRegularSymbols(gr);
    addToFile(gr);
}

loc pos = |project://syntax-highlighter/outputs/testOutput.txt|;
void resetFile() = writeFile(pos, "");
void addToFile(value text) = writeFile(pos, readFile(pos)+"<text>\n\n");