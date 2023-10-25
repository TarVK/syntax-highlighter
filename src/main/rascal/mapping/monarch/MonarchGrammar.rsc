module mapping::monarch::MonarchGrammar

data MonarchGrammar = monarchGrammar(
    str \start,
    map[str, MonarchStateDefinition] tokenizer,
    bool includeLF = false,
    str defaultToken = ""
);

alias MonarchStateDefinition = list[MonarchRule];
data MonarchRule
    = tokenRule(str regex, list[MonarchAction] action)
    | includeRule(str include);

data MonarchAction 
    = stateChange(str token, str next)
    | token(str token);


// Note: monarch does not support lookbehinds outside the capture, since the regex matcher is not advanced to start looking from a certain index, but instead pretends any of the laready matched/skipped input of a line does not exist by trimming it. 
/* 
    Output JSON grammars have to be converted to JS (specifically the regular expressions), by running it through this function:
    ```
    function loadGrammar({tokenizer, ...grammar}) {
        tokenizer = Object.fromEntries(
            Object.entries(tokenizer).map(
                ([sym, rules])=>
                    [sym, rules.map(rule=>"regex" in rule 
                        ? {...rule, regex: RegExp(rule.regex)} 
                        : rule)]
            )
        );
        // Make sure that start is the first line
        return {...grammar, tokenizer};
    };
    ```

    Or inline (handy for https://microsoft.github.io/monaco-editor/monarch.html)
    ```
    (({tokenizer, ...grammar})=>{
        tokenizer = Object.fromEntries(
            Object.entries(tokenizer).map(
                ([sym, rules])=>
                    [sym, rules.map(rule=>"regex" in rule 
                        ? {...rule, regex: RegExp(rule.regex)} 
                        : rule)]
            )
        );
        // Make sure that start is the first line
        return {...grammar, tokenizer};
    })(GRAMMARINPUT);
    ```
*/