module Scope

@doc {
    Textmate scopes work as follows:
    - Each scope consists of multiple hierarchical parts, separated by a dot. E.g. "constant.character.escape.untitled"
    - Each textual element can fall under multiple scopes, which are sorted by depth of the scope occurence in the tree. Selectors specify these using comma seperators and may make use of this ordering, e.g. "string, constant" is different from "constant, string". Here "string, constant"  would represent that "constant" was defined further towards the leave than "string"
}
alias Scope = str;
alias ScopeList = list[Scope];

// We use this weird syntax instead of just a list of items, such that elements are appropriately comparable using `<` which is required for minimal PSNFA uniqueness
data Scopes = noScopes()
            | someScopes(Scopes bottom, Scope top); // Top being most towards the leaf, top in vscode's token stack

str stringify(someScopes(noScopes(), scope)) = scope;
str stringify(someScopes(rest, scope)) = "<stringify(rest)>,<scope>";
str stringify(noScopes()) = "";

list[Scope] toList(noScopes()) = [];
list[Scope] toList(someScopes(first, last)) = toList(first) + last;

Scopes toScopes([]) = noScopes();
Scopes toScopes([*first, last]) = someScopes(toScopes(first), last);

Scopes concat(Scopes head, Scopes tail) = toScopes(toList(head) + toList(tail));