module testing::terminalCategoriesTest

import Grammar;
import lang::rascal::format::Grammar;
import IO;

import transformations::Normalize;
import transformations::TerminalCategories;
import transformations::SymbolSimplify;

// syntax A = @category="test" 'a'*;


syntax A = @category="A" B
        | @category="A" C;
syntax B = @category="B" 'b' D;
syntax C = @category="C" 'c' D;
syntax D = @category="D" 'd'*;

void main() {
    Grammar gr = grammar(#A);
    gr = normalize(gr);
    gr = pushCategoriesToTerminals(gr, ancestorCategories);
    // gr = pushCategoriesToTerminals(gr, latestCategories);
    println(gr);
    gr = simplifySymbols(gr);

    str grText = grammar2rascal(gr);    
    loc pos = |project://syntax-highlighter/outputs/grammarOutput.rsc|;
    writeFile(pos, "module something\n"+grText);
}