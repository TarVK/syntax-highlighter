module Scope

import util::List;

@doc {
    Textmate scopes work as follows:
    - Each scope consists of multiple hierarchical parts, separated by a dot. E.g. "constant.character.escape.untitled"
    - Each textual element can fall under multiple scopes, which are sorted by depth of the scope occurence in the tree. Selectors specify these using comma seperators and may make use of this ordering, e.g. "string, constant" is different from "constant, string". 
}
alias Scopes = list[Scope];
alias Scope = list[str];

str stringify(Scopes scopes) = stringify([stringify(scope, ".") | scope <- scopes], ",");