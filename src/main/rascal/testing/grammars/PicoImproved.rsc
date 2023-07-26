module testing::grammars::PicoImproved

start syntax A  = program: "begin" Declarations decls {Statement  ";"}* body "end" ;

syntax Declarations  = "declare" {IdType ","}* decls ";" ;  
syntax IdType = idtype: Id id ":" Type t;

syntax Statement 
  = assign: () !>> StatementKW Id var ":="  Expression val 
  | cond: "if" Expression cond "then" {Statement ";"}*  thenPart "else" {Statement ";"}* elsePart "fi"
  | cond: "if" Expression cond "then" {Statement ";"}*  thenPart "fi"
  | loop: "while" Expression cond "do" {Statement ";"}* body "od"
  ;  

keyword StatementKW = "if" | "while";
     
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
lexical Natural = [0-9]+ !>> [0-9];
lexical String = "\"" ![\"]*  "\"";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];

lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="Comment" "%" ![%]+ "%"
//    | @category="Comment" "%%" ![\n]* $
   ;