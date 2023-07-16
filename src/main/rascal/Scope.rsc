module Scope

import util::List;

alias Scopes = list[Scope];
alias Scope = list[str];

str stringify(Scopes scopes) = stringify([stringify(scope, ".") | scope <- scopes], ",");