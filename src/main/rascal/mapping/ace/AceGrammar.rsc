module mapping::ace::AceGrammar

alias AceGrammar = map[str, AceStateDefinition];

alias AceStateDefinition = list[AceRule];
data AceRule
    = tokenRule(str regex, list[str] token)
    | pushRule(str regex, list[str] token, str push)
    | nextRule(str regex, list[str] token, str next) // Used for pop when next=pop
    | includeRule(str include);