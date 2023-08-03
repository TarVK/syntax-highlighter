module conversion::shapeConversion::ShapeConversion

import Set;
import List;
import Relation;

import conversion::conversionGrammar::ConversionGrammar;
import conversion::shapeConversion::makePrefixedRightRecursive;
import conversion::shapeConversion::deduplicateProductions;
import Warning;


@doc {
    Converts the language to be in the shape expected by syntax highlighters.

    The expectation on the input grammar is:
        - No modifiers are present 
        - Regex conversion has been performed (not required, but unlikely to work without warnings otherwise)

    The guarantee on the output grammar is:
        - The language accepted by the output is a superset of that of the input
        - The grammar is deterministic (unless warnings are generated)
        - Every production has one of the shapes:
            - A -> X B!             (where B may equal A)
            - A -> X B! A!          
            - A -> (<s> X B! Y) A!  (where B may equal A)
            - A -> 
        - Every symbol at least has the empty production
}
WithWarnings[ConversionGrammar] convertToShape(ConversionGrammar grammar) {
    <warnings, grammar> = makePrefixedRightRecursive(grammar);
    grammar = deduplicateProductions(grammar);
    return <warnings, grammar>;
}