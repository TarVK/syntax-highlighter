module Scope

@doc {
    Textmate scopes work as follows:
    - Each scope consists of multiple hierarchical parts, separated by a dot. E.g. "constant.character.escape.untitled"
    - Each textual element can fall under multiple scopes, which are sorted by depth of the scope occurence in the tree. Selectors specify these using comma seperators and may make use of this ordering, e.g. "string, constant" is different from "constant, string". 
}
alias Scope = str;
alias ScopeList = list[Scope];

// We use this weird syntax instead of just a list of items, such that elements are appropriately comparable using `<` which is required for minimal PSNFA uniqueness
data Scopes = noScopes()
            | someScopes(Scope top, Scopes bottom);

str stringify(someScopes(scope, noScopes())) = scope;
str stringify(someScopes(scope, rest)) = "<scope>,<stringify(rest)>";
str stringify(noScopes()) = "";

list[Scope] toList(noScopes()) = [];
list[Scope] toList(someScopes(first, last)) = first + toList(last);

Scopes toScopes([]) = noScopes();
Scopes toScopes([first, *last]) = someScopes(first, toScopes(last));

Scopes concat(Scopes head, Scopes tail) = toScopes(toList(head) + toList(tail));