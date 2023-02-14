module Main

import ParseTree;
import Grammar;
import IO;

lexical I = [A-Za-z][A-Za-z0-9]+;

syntax S
    = I ":=" E ";"
    | "if" "(" E ")" S "else" S
    | "{" S* "}"
    | "while" "(" E ")" S
    ;

syntax E
    = "e"
    | E "*" E
    > E "+" E
    ;

int main() {
   println(#E);
   return 0;
}
