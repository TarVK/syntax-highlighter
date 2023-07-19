module testing::regexConversionTest

import IO;
import Grammar;
import ParseTree;

import Visualize;
import conversionGrammar::ConversionGrammar;
import conversionGrammar::regexConversion::RegexConversion;

// syntax A = @token="b" B "a" B "i"
//          | @token="b" B "ce" B "i"
//          | @token="b" B "d" B "i"
//          | @token="b" B "a" C+ "o"
//          | @token="b" B "ce" C+ "o"
//          | @token="b" B "d" C+ "o"
//          | "a" B >> D "c"
//          | "b" B >> D "c"
//          | "c"
//          | "d";
// syntax B = "b"
//          | "ab"
//          | @scope="C" C;
// syntax C = @token="c" "c"
//          | @token="c" "ac";
// syntax D = E
//          | E D
//          | @token="rd" D "D";
// syntax E = @scope="rd" F;
// syntax F = [a-z];

// syntax A = @scope="B" B;
// syntax B = @token="d,b" "b";

// syntax A = "a" B "c" B
//          | "b" B "c" B
//          | B "c" B
//          | "a" B B
//          | "b" B B
//          | B B;


// syntax A = "a" B "c" B
//          | "a" B B;


// syntax A = [\ \t\n\r]
//    | "%"
//    | "%%" ![\n]* $
//    ;
// syntax A = "a"
//          | "b"
//          | "c"+;

// syntax A = idtype: ":" Type t;
// syntax Type 
//   = natural:"natural" 
//   | string :"string" 
//   | nil    :"nil-type"
//   ;


start syntax A  = program: "begin" Declarations decls {Statement  ";"}* body "end" ;

syntax Declarations  = "declare" {IdType ","}* decls ";" ;  
syntax IdType = idtype: Id id ":" Type t;

syntax Statement 
  = assign: Id var ":="  Expression val 
  | cond: "if" Expression cond "then" {Statement ";"}*  thenPart "else" {Statement ";"}* elsePart "fi"
  | cond: "if" Expression cond "then" {Statement ";"}*  thenPart "fi"
  | loop: "while" Expression cond "do" {Statement ";"}* body "od"
  ;  
     
syntax Type 
  = natural:"natural" 
  | string :"string" 
  | nil    :"nil-type"
  ;

syntax Expression 
  = id: Id name
  | strcon: String string
  | natcon: Natural natcon
  | bracket "(" Expression e ")"
  > left concat: Expression lhs "||" Expression rhs
  > left ( add: Expression lhs "+" Expression rhs
         | min: Expression lhs "-" Expression rhs
         )
  ;

lexical Id  = [a-z][a-z0-9]* !>> [a-z0-9];
lexical Natural = [0-9]+ ;
lexical String = "\"" ![\"]*  "\"";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];

lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="Comment" "%" ![%]+ "%"
   | @category="Comment" "%%" ![\n]* $
   ;

void main() {
    if(<warnings, conversionGrammar> := toConversionGrammar(#A)){
        conversionGrammar = convertToRegularExpressions(conversionGrammar);
        conversionGrammar = stripConvSources(conversionGrammar);
        stdGrammar = fromConversionGrammar(conversionGrammar);

        visualize(<
            grammar(#A),
            stdGrammar
        >);

        if(size(warnings)>0) println(warnings);

        // loc pos = |project://syntax-highlighter/outputs/regexGrammar.txt|;
        // writeFile(pos, "<stdGrammar>");
    }
}