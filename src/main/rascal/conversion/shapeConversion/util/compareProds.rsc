module conversion::shapeConversion::util::compareProds

import ParseTree;

import conversion::shapeConversion::util::getComparisonProds;
import conversion::conversionGrammar::ConversionGrammar;

@doc {
    Checks whether two sets of productions are structurally equivalent (if the irrelevant naming + metadata is ignored)
}
bool equals(set[ConvProd] prodsA, set[ConvProd] prodsB) = getComparisonProds(prodsA) == getComparisonProds(prodsB);


@doc {
    Checks whether a set of productions prodsA is structurally a non-strict subset of a set of productions prodsB (if the irrelevant naming + metadata is ignored)
}
bool isSubset(set[ConvProd] prodsA, set[ConvProd] prodsB) = getComparisonProds(prodsA) <= getComparisonProds(prodsB);