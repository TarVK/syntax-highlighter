module testing::automated::tests::exponentialMerging::ExponentialMergingTest

import ValueIO;
import IO;

import Logging;
import Warning;
import TestConfig;
import convertGrammar;
import testing::util::visualizeGrammars;
import conversion::conversionGrammar::ConversionGrammar;
import conversion::conversionGrammar::fromConversionGrammar;
import testing::automated::setup::calculateInputData;
import regex::Regex;
import regex::PSNFATools;
import regex::RegexCache;

syntax Merge3 = A A Merge3
              | A A Merge3 B Merge3
              | C C Merge3
              | C C Merge3 D Merge3
              | E E Merge3
              | E E Merge3 F Merge3
              | G;
lexical A     = @category="1"  "a";
lexical B     = @category="2"  "b";
lexical C     = @category="3"  "c";
lexical D     = @category="4"  "d";
lexical E     = @category="5"  "e";
lexical F     = @category="6"  "f";
lexical G     = @category="7"  "g";
      
layout Layout = [\ \t\n\r]* !>> [\ \t\n\r];

test bool createExponentiallyManyStates() {
    inputFolder = |project://syntax-highlighter/src/main/rascal/testing/automated/tests/exponentialMerging|;
    calculateGrammar(
        #Merge3, 
        inputFolder,
        autoTestConfig(),
        {conversionGrammarOutput()}
    );
    generatePath = getGeneratePath(inputFolder);
    conversionGrammar = readBinaryValueFile(#ConversionGrammar, generatePath+"conversionGrammar.bin");

    universe = {"b", "d", "f"};
    split: for({*inChars, *outChars} := universe) {
        inRegexes = {getCachedRegex(parseRegexReduced(char)) | char <- inChars};
        outRegexes = {getCachedRegex(parseRegexReduced(char)) | char <- outChars};

        findSym: for(sym <- conversionGrammar.productions<0>) {
            productions = conversionGrammar.productions[sym];

            bool matches = false;
            for(inRegex <- inRegexes) 
                if(!existsProductionWithPrefix(productions, inRegex)) 
                    continue findSym;
            for(outRegex <- outRegexes) 
                if(existsProductionWithPrefix(productions, outRegex)) 
                    continue findSym;

            continue split;
        }

        // Mo matching symbol found for this split
        return false;
    }

    // visualizeGrammars(fromConversionGrammar(conversionGrammar));
    return true;
}

bool existsProductionWithPrefix(set[ConvProd] prods, Regex regex) {
    for(convProd(_, [regexp(r), *rest]) <- prods) {
        if(isSubset(regex, r, true)) 
            return true;
    }
    return false;
}