module testing::grammars::StructuredLanguage

syntax Program = Declaration*;

syntax Declaration 
    = VariableDeclaration
    | FunctionDeclaration
    | "interface" TypeDeclaration "{" Declaration* "}"
    | "class" TypeDeclaration ("extends" Type)? ("implements" {Type ","}+)? "{" Declaration* "}"
    ;

syntax Stmt 
    = forIn: "for" "(" Variable "in" Exp ")" Stmt
    | forIter: "for" "(" Exp ";" Exp ";" Exp ")" Stmt
    | iff: "if" "(" Exp ")" Stmt
    | iffElse: "if" "(" Exp ")" Stmt "else" !>> [a-zA-Z0-9] Stmt
    | "{" Stmt* "}"
    | assign: Variable "=" Exp ";"
    | retrn: "return" Exp ";"
    | Exp ";"
    | VariableDeclaration
    | FunctionDeclaration
    ;

syntax Exp 
    = brac: "(" Exp ")"
    | add: Exp "+" Exp
    | mult: Exp "*" Exp
    | subt: Exp "-" Exp
    | divide: Exp "/" Exp
    | equals: Exp "==" Exp
    | inn: Exp "in" Exp
    | var: Variable
    | string: Str
    | booll: Bool
    | nat: Natural
    | lst: "[" {Exp ","}* "]"
    | call: Exp "(" {Exp ","}* ")"
    | access: Exp "." Exp
    ;

syntax TypeDeclaration = TypeVariable ("\<" {TypeVariable ","}+ "\>")?;
syntax VariableDeclaration = varDeclaration: Modifiers Type Variable "=" Exp ";";
syntax FunctionDeclaration = varDeclaration: Modifiers Type Variable "(" {Parameter ","}* ")" "{" Stmt* "}";
syntax Modifiers = ("public"|"protected"|"private")? "static"?;

syntax Type
    = baseType: TypeVariable
    | arrayType: Type "[]"
    | genericType: Type "\<" Type "\>"
    | primitiveType: [a-zA-Z0-9] !<< PrimitiveType !>> [a-zA-Z0-9]
    ;
syntax PrimitiveType
    = @category="storage.type" string: "string"
    | @category="storage.type" float: "float"
    | @category="storage.type" boolean: "boolean"
    | @category="storage.type" intt: "int"
    | @category="storage.type" voidd: "void"
    ;

lexical Parameter = @category="variable.parameter" Id;
lexical Variable = @category="variable" Id;
lexical TypeVariable = @category="storage.type" Id;

keyword KW = "for"|"in"|"if"|"true"|"false"|"else"|"return"|"int"|"boolean"|"float"|"string"|"void"|"public"|"private"|"protected"|"static"|"extends"|"implements"|"interface"|"class";

lexical Id = ([a-zA-Z0-9] !<< [a-z][a-zA-Z0-9]* !>> [a-zA-Z0-9]) \ KW;
lexical Natural = @category="constant.numeric" [a-zA-Z0-9] !<< [0-9]+ !>> [a-zA-Z0-9];
lexical Bool = [a-zA-Z0-9] !<< (True|False) !>> [a-zA-Z0-9];
lexical True = @category="constant.language" "true";
lexical False = @category="constant.language" "false";
lexical Str =  @category="string.template" "\"" Char* "\"";
lexical Char = char: ![\\\"$]
             | dollarChar: "$" !>> "{"
             | @categoryTerm="constant.character.escape" escape: "\\"![]
             | @category="meta.embedded.line" @categoryTerm="punctuation.definition.template-expression" embedded: "${" Layout Exp Layout "}";

layout Layout = WhitespaceAndComment* !>> [\ \t\n\r%];
lexical WhitespaceAndComment 
   = [\ \t\n\r]
   | @category="comment.block" "/*" ![%]+ "*/"
   | @category="comment.line" "//" ![\n]* $
   ;