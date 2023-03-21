module testing::mohriNederhofTest

import Grammar;
import ParseTree;
import IO;
import Set;
import Type;
import lang::rascal::format::Grammar;

import transformations::Normalize;
import transformations::SymbolSimplify;
import transformations::util::GrammarComponents;
import transformations::MohriNederhof;

// syntax A = @category="A" 'a'*;
// syntax B = @category="B" 'b'
//         | @category="D" 'd';
// syntax D = A C;
// syntax C = @category="C" D B
//         | ;

// syntax C2 = @category="C" @category="D" A C2 B
//         | ;



syntax Never = ;

syntax E = E "+" T
         | T;
syntax T = T "*" F
         | F;
syntax F = "(" E ")"
         | [a-z];


void main() {
    Grammar gr = grammar(#E);
    gr = normalize(gr);
    // comps = getGrammarComponents(gr);
    // println(comps);

    gr = approximateMohriNederhof(gr);

    println(gr);
    println(getGrammarComponents(gr));
    
    gr = simplifySymbols(gr);
    str grText = grammar2rascal(gr);    
    loc pos = |project://syntax-highlighter/outputs/grammarOutput.rsc|;
    writeFile(pos, "module something\n"+grText);

    println(parse(getGrammarType(gr), "(b+(d)", allowAmbiguity=true));
    
    // println(parse(type(takeOneFrom(gr.starts), gr.rules), "(a * b + c)"));
}

type[Tree] getGrammarType(Grammar grammar) {
    switch (type(takeOneFrom(grammar.starts)<0>, grammar.rules)) {
        case type[Tree] tree: return tree;
        default:  return #Never;
    };
} 