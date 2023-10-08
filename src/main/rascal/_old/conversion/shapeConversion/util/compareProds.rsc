module conversion::shapeConversion::util::compareProds

import ParseTree;

import conversion::shapeConversion::util::getComparisonProds;
import conversion::conversionGrammar::ConversionGrammar;

// TODO: Make the algorithms consider that different regular expressions may specify the same thing 
@doc {
    Checks whether two sets of productions are structurally equivalent (if the irrelevant naming + metadata is ignored)
}
bool equals(set[ConvProd] prodsA, set[ConvProd] prodsB, set[Symbol] selfSet) 
    = equals(getComparisonProds(prodsA, selfSet), getComparisonProds(prodsB, selfSet));

bool equals(set[ConvProd] prodsA, set[ConvProd] prodsB)
    = prodsA == prodsB;

@doc {
    Checks whether a set of productions prodsA is structurally a non-strict subset of a set of productions prodsB (if the irrelevant naming + metadata is ignored)
}
bool isSubset(set[ConvProd] prodsA, set[ConvProd] prodsB, set[Symbol] selfSet)
    = isSubset(getComparisonProds(prodsA, selfSet), getComparisonProds(prodsB, selfSet));

bool isSubset(set[ConvProd] prodsA, set[ConvProd] prodsB)
    = prodsA <= prodsB;