module mapping::monarch::MonarchGrammar

data MonarchGrammar = monarchGrammar(
    map[str, MonarchStateDefinition] tokenizer,
    str defaultToken = ""
);

alias MonarchStateDefinition = list[MonarchRule];
data MonarchRule
    = tokenRule(str regex, list[MonarchAction] action)
    | includeRule(str include);

data MonarchAction 
    = stateChange(str token, str next)
    | token(str token);