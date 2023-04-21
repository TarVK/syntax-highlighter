module testing::searchTest

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


syntax Never = ;

syntax Expr1 =
  [*] Expr 
  | [)] Expr1 
  | 
  | right [+] Expr 
  ;

syntax Expr =
  [a-z] Expr1 
  | [(] Expr 
  ;

syntax Stmt1 =
  Stmt 
  | [}] Stmt1  
  |
  ;


syntax Stmt = [a-z] [=] Expr Stmt1 
  | [i] [f] [(] Expr [)] Stmt 
  | [{] Stmt1 
//   | [w] [h] [i] [l] [e] [(] Expr [)] Stmt
//   | [f] [o] [r] [(] Expr [;] Expr [;] Expr [)] Stmt
  ;


void main() {
    Grammar gr = grammar(#Stmt);
    // gr = removeEmpty(gr);


    suffixes = getSuffixes(gr);
    loc pos2 = |project://syntax-highlighter/outputs/suffixes.txt|;
    writeFile(pos2, "<suffixes>");
}

type[Tree] getGrammarType(Grammar grammar) {
    switch (type(takeOneFrom(grammar.starts)<0>, grammar.rules)) {
        case type[Tree] tree: return tree;
        default:  return #Never;
    };
} 