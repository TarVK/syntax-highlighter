module mapping::monarch::MonarchGrammar

data MonarchGrammar = monarchGrammar(
    str \start,
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

/* 
    Output JSON grammars have to be converted to JS (specifically the regular expressions), by running it through this function:
    ```
    function loadGrammar({start, tokenizer, ...grammar}) {
        tokenizer = Object.fromEntries(
            Object.entries(tokenizer).map(
                ([sym, rules])=>
                    [sym, rules.map(rule=>"regex" in rule 
                        ? {...rule, regex: RegExp(rule.regex)} 
                        : rule)]
            )
        );
        // Make sure that start is the first line
        return {...grammar, tokenizer: {[start]: tokenizer[start], ...tokenizer}};
    };
    ```

    Or inline (handy for https://microsoft.github.io/monaco-editor/monarch.html)
    ```
    (({start, tokenizer, ...grammar})=>{
        tokenizer = Object.fromEntries(
            Object.entries(tokenizer).map(
                ([sym, rules])=>
                    [sym, rules.map(rule=>"regex" in rule 
                        ? {...rule, regex: RegExp(rule.regex)} 
                        : rule)]
            )
        );
        // Make sure that start is the first line
        return {...grammar, tokenizer: {[start]: tokenizer[start], ...tokenizer}};
    })(GRAMMARINPUT);
    ```
*/