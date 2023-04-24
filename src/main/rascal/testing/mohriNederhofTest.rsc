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
import transformations::simplify::RemoveEmpty;
import transformations::simplify::RemoveSelfLoop;
import transformations::simplify::SubstituteUnitRules;
import transformations::simplify::RemoveUnusedRules;
import transformations::simplify::CombineCharacters;

import search::ApplicableSuffixSearch;

// import testing::grammars::JS;

// syntax A = @category="A" 'a'*;
// syntax B = @category="B" 'b'
//         | @category="D" 'd';
// syntax D = A C;
// syntax C = @category="C" D B
//         | ;

// syntax C2 = @category="C" @category="D" A C2 B
//         | ;



syntax Never = ;

// syntax E = E "+" T
//          | T;
// syntax T = T "*" F
//          | F;
// syntax F = "(" E ")"
//          | [a-z];

syntax Stmt = iff: "if" "(" Expr ")" Stmt
            | whilee: "while" "(" Expr ")" Stmt
            | forr: "for" "(" Expr ";" Expr ";" Expr ")" Stmt
            | brackett: "{" Stmt* "}"
            | @category="assignment" assign: [a-z] "=" Expr;

syntax Expr = right plus: Expr "+" Expr
         > left times: Expr "*" Expr
         > brackett: "(" Expr ")"
         > @category="identifier" identifier: [a-z];

void main() {
    Grammar gr = grammar(#Stmt);
    // Grammar gr = grammar(#E);
    // Grammar gr = grammar(#Source);
    gr = normalize(gr);

    // println(gr);
    // println(getGrammarComponents(gr));
    // println(getDependencies(grammar(#Source)));

    gr = substituteUnitRules(gr);
    gr = removeSelfLoop(gr);
    gr = removeEmpty(gr);
    gr = removeUnusedRules(gr);
    gr = approximateMohriNederhof(gr);
    // gr = combineCharacters(gr);

    println(gr);
    
    // gr = simplifySymbols(gr);
    // str grText = grammar2rascal(gr);    
    // loc pos = |project://syntax-highlighter/outputs/grammarOutput.rsc|;
    // writeFile(pos, "module something\n"+grText);

    // suffixes = filterCharacterCompatibilities(getApplicableSuffixes(gr), gr);
    suffixes = getApplicableSuffixes(gr);
    flattenedSuffixes = (prod: {getSuffix(s) | s <- suffixes[prod]} | prod <- suffixes);
    loc pos2 = |project://syntax-highlighter/outputs/suffixes.txt|;
    writeFile(pos2, "<flattenedSuffixes>");
}

type[Tree] getGrammarType(Grammar grammar) {
    switch (type(takeOneFrom(grammar.starts)<0>, grammar.rules)) {
        case type[Tree] tree: return tree;
        default:  return #Never;
    };
} 