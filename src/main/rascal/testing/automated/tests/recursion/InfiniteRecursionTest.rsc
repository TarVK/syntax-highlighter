module testing::automated::tests::recursion::InfiniteRecursionTest

import Logging;
import Warning;
import TestConfig;
import regex::RegexTypes;
import regex::RegexCache;
import conversion::util::makeLookahead;
import conversion::conversionGrammar::toConversionGrammar;
import conversion::regexConversion::convertToRegularExpressions;
import conversion::prefixConversion::convertToPrefixed;
import conversion::shapeConversion::convertToShape;

syntax Merge2 = A Merge2
              | A Merge2 B Merge2
              | C;
lexical A     = @category="1"  "a";
lexical B     = @category="2"  "b";
lexical C     = @category="3"  "c";
      
layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];

test bool recursesInfinitely() {
    log = standardLogger();

    <_, conversionGrammar> = toConversionGrammar(#Merge2, log);
    <_, conversionGrammar> = convertToRegularExpressions(conversionGrammar, log);
    <_, conversionGrammar> = convertToPrefixed(conversionGrammar, log);

    // Decide on an arbitrarily high constant cap
    int cap = 16;

    eof = getCachedRegex(makeLookahead(never()));
    <_, _, iterations> 
        = convertToShapeWithIterations(
            conversionGrammar, 
            eof, 
            testConfig(
                log = log, 
                detectRecursion=false, 
                overlapFinishRegex=true,
                lastPhase=shapeConversion(maxIterations=cap)
            )
        );

    return iterations>=cap;
}