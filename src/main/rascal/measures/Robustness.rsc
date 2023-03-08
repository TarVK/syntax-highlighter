@synopsis{A robustness measure}
@description{
    `getRobustnessPenalty` defines a measure that determines how well a tokenization corresponds to the one defined by a given grammar, for inputs that may be syntactically incorrect.
    A lower score score is better, since this measure describes a penalty. 

    The penalty is the sum token differences per character. Where the token differences for one character are described as the sum of additional and missing tokens. 
}

module measures::Robustness

import IO;
import ParseTree;
import String;
import measures::util::Tokenization;
import measures::util::TokenComparison;

// Nodification text utils
public data ModificationSection = Insertion(str text) | Deletion(str text) | Unchanged(str text);
public alias ModifiedText = list[ModificationSection];

public str getAfterText([]) = "";
public str getAfterText([Insertion(text), *rest]) = text + getAfterText(rest);
public str getAfterText([Deletion(text), *rest]) = getAfterText(rest);
public str getAfterText([Unchanged(text), *rest]) = text + getAfterText(rest);

public str getBeforeText([]) = "";
public str getBeforeText([Insertion(text), *rest]) = getBeforeText(rest);
public str getBeforeText([Deletion(text), *rest]) = text + getBeforeText(rest);
public str getBeforeText([Unchanged(text), *rest]) = text + getBeforeText(rest);

// Tokenization extraction utils
public data ModificationType = Insert() | Delete() | Keep();
public alias ModificationList = list[ModificationType];

public ModificationList getModificationList([]) = [];
public ModificationList getModificationList([Insertion(text), *rest]) = [Insert() | _<-[0..size(text)]] + getModificationList(rest);
public ModificationList getModificationList([Deletion(text), *rest]) = [Delete() | _<-[0..size(text)]] + getModificationList(rest);
public ModificationList getModificationList([Unchanged(text), *rest]) = [Keep() | _<-[0..size(text)]] + getModificationList(rest);

public ModificationList getBeforeModifications(ModificationList types) = [t | t <- types, t!=Insert()];
public ModificationList getAfterModifications(ModificationList types) = [t | t <- types, t!=Delete()];

public Tokenization getCommonTokenization([], []) = [];
public Tokenization getCommonTokenization([CharacterTokens token, *rTokens], [Keep(), *rTypes]) = token + getCommonTokenization(rTokens, rTypes);
public Tokenization getCommonTokenization([CharacterTokens token, *rTokens], [_, *rTypes]) = getCommonTokenization(rTokens, rTypes);

// The main measure
public tuple[Tokenization, Tokenization] getCommonTokenization(type[Tree] spec, type[Tree] highlighter, ModifiedText text) {
    ModificationList charTypes = getModificationList(text);

    str specText = getBeforeText(text);
    Tokenization specTokenization = getTokenization(spec, specText);
    Tokenization commonSpecTokenization = getCommonTokenization(specTokenization, getBeforeModifications(charTypes));

    str highlightText = getAfterText(text);
    Tokenization highlightTokenization = getTokenization(highlighter, highlightText);
    Tokenization commonHighlightTokenization = getCommonTokenization(highlightTokenization, getAfterModifications(charTypes));

    return <commonSpecTokenization, commonHighlightTokenization>;
}
public TokenizationDifferences getCommonTokenizationDifferences(type[Tree] spec, type[Tree] highlighter, ModifiedText text) {
    <commonSpecTokenization, commonHighlightTokenization> = getCommonTokenization(spec, highlighter, text);
    return getTokenDifferences(commonSpecTokenization, commonHighlightTokenization);
}
public int getRobustnessPenalty(type[Tree] spec, type[Tree] highlighter, ModifiedText text) = getDifferenceCount(getCommonTokenizationDifferences(spec, highlighter, text));