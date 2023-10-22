module mapping::common::normalizeScopeTags

import Scope;
import Warning;

@doc {
    Normalizes the scope tags of a regular expression, such that every character of a match is always assigned exactly 1 scope. The defaultScope is used as the scope to assign for characters that had no assigned scopes. If the input regex specifies to apply multiple scopes, the latest one is chosen, and a warning is added to the output. 
}
WithWarnings[Regex] normalizeScopeTags(Regex regex, Scope defaultScope) {

}