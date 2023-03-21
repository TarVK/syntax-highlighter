module testing::grammars::LambdaJS

layout Whitespace = WhitespaceAndComment* !>> [\t-\n\r\ ] !>> "//";
lexical WhitespaceAndComment 
    = [\t-\n\r\ ]
    | @category="comment" "//" ![\n]* $;
    
lexical Identifier = [a-zA-Z0-9@$_\[\]{}\<\>&|+\-*/\\!%^#?,.:\'\"]+ \ "output" !>> [a-zA-Z0-9@$_\[\]{}\<\>&|+\-*/\\!%^#?,.:\'\"] !>> "//";
start syntax Program = Statement*;
syntax Statement = Output
				 | Declaration;
syntax Declaration = Function
				   | Constructor;
syntax ConstructorName = @category="variable.function" Identifier;
syntax Constructor = ConstructorName Identifier* SC;
				    
syntax Function = Structure EQ Expression SC;
syntax SimpleStructure =  @category="variable.parameter" Identifier
				       |  @category="variable.parameter" bracket LB Structure RB;
syntax Structure = Identifier SimpleStructure*; 
syntax SimpleExpression = Identifier 
						| bracket LB Expression RB; 
syntax Expression = SimpleExpression+; 
syntax OutputKeyword = @category="keyword" "output";
syntax Output = OutputKeyword Expression SC;

syntax EQ = @category="symbol" "=";
syntax LB = @category="symbol" "(";
syntax RB = @category="symbol" ")";
syntax SC = @category="symbol" ";";