module testing::simplificationTest

import Grammar;
import lang::rascal::format::Grammar;
import IO;

import transformations::Normalize;
import transformations::SymbolSimplify;

syntax A = @category="test" 'a'*;
void main() {
    Grammar gr = grammar(#A);
    gr = normalize(gr);
    gr = simplifySymbols(gr);
    // println(gr);
    // println("<#A>");

    str grText = grammar2rascal(gr);
    println(grText);

    
    loc pos = |project://syntax-highlighter/outputs/grammarOutput.rsc|;
     writeFile(pos, "module something\n"+grText);
}