module mapping::pygments::PygmentsGrammar

alias PygmentsGrammar = map[str, PygmentsStateDefinition];

alias PygmentsStateDefinition = list[PygmentsRule];
data PygmentsRule
    = tokenRule(str regex, list[str] token)
    | pushRule(str regex, list[str] token, str push)
    | includeRule(str include);
