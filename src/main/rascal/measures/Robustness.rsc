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

public str getBeforeText(ModifiedText text) =  ("" | it + section.text | section <- text, !(Insertion(_) := section));
public str getAfterText(ModifiedText text) = ("" | it + section.text | section <- text, !(Deletion(_) := section));

// Tokenization extraction utils
public data ModificationType = Insert() | Delete() | Keep();
public alias ModificationTypes = list[ModificationType];

public ModificationType getTypeFromSection(ModificationSection section) { switch (section) {
    case Insertion(_): return Insert();
    case Unchanged(_): return Keep();
    default: return Delete();
} }
public ModificationTypes getModificationTypes(ModifiedText text) = [*[t | _<-[0..size(s.text)]] | s<-text, t := getTypeFromSection(s)];

public ModificationTypes getBeforeModifications(ModificationTypes types) = [t | t <- types, t!=Insert()];
public ModificationTypes getAfterModifications(ModificationTypes types) = [t | t <- types, t!=Delete()];

public Tokenization getCommonTokenization(Tokenization tokens, ModificationTypes types) = [token | <token, t> <- zip2(tokens, types), Keep():=t];
public Tokenization getCommonTokenization(type[Tree] grammar, str text, ModificationTypes modifications) 
    = getCommonTokenization(getTokenization(grammar, text), modifications);

public Tokenization getBeforeTokenization(type[Tree] grammar, ModifiedText text) =
    getCommonTokenization(grammar, getBeforeText(text), (getBeforeModifications o getModificationTypes)(text));    
public Tokenization getAfterTokenization(type[Tree] grammar, ModifiedText text) =
    getCommonTokenization(grammar, getAfterText(text), (getAfterModifications o getModificationTypes)(text));

// The main measure
public TokenizationDifferences getCommonTokenizationDifferences(type[Tree] spec, type[Tree] highlighter, ModifiedText text) 
    = getTokenDifferences(getBeforeTokenization(spec, text), getAfterTokenization(highlighter, text));
public int getRobustnessPenalty(type[Tree] spec, type[Tree] highlighter, ModifiedText text) 
    = getDifferenceCount(getCommonTokenizationDifferences(spec, highlighter, text));

public TokenizationDifferences getCommonTokenizationDifferences(type[Tree] spec, Tokenization highlighting, ModifiedText text) 
    = getTokenDifferences(getBeforeTokenization(spec, text), highlighting);
public int getRobustnessPenalty(type[Tree] spec, Tokenization highlighting, ModifiedText text) 
    = getDifferenceCount(getCommonTokenizationDifferences(spec, highlighting, text));