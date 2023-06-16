module testing::grammars::LambdaJSnew

layout Whitespace = WhitespaceAndComment* !>> [\t-\n\r\ ] !>> "//";
lexical WhitespaceAndComment 
    = [\t-\n\r\ ]
    | @token="comment" "//" ![\n]* $;
    
lexical Identifier = [a-zA-Z0-9@$_\[\]{}\<\>&|+\-*/\\!%^#?,.:\'\"]+ \ "output" !>> [a-zA-Z0-9@$_\[\]{}\<\>&|+\-*/\\!%^#?,.:\'\"] !>> "//" ;
start syntax Program = Statement*;
syntax Statement = Output
				 | Declaration;
syntax Declaration = Function
				   | Constructor;
syntax ConstructorName = @scope="variable.function" Identifier;
syntax Constructor = ConstructorName Identifier* SC;
				    
syntax Function = @token="symbol" Structure "=" Expression SC;
syntax SimpleStructure =  @scope="variable.parameter" Identifier
				       |  @scope="variable.parameter" bracket LB Structure RB;
syntax Structure = Identifier SimpleStructure*; 
syntax SimpleExpression = Identifier
						| bracket LB Expression RB; 
syntax Expression = SimpleExpression+; 
syntax OutputKeyword = @token="keyword" "output";
syntax Output = OutputKeyword Expression SC;

syntax LB = @token="symbol" "(";
syntax RB = @token="symbol" ")";
syntax SC = @category="symbol" ";";