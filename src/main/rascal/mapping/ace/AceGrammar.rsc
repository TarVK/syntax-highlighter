module mapping::ace::AceGrammar

alias AceGrammar = map[str, AceStateDefinition];

alias AceStateDefinition = list[AceRule];
data AceRule
    = tokenRule(str regex, list[str] token)
    | pushRule(str regex, list[str] token, str push)
    | nextRule(str regex, list[str] token, str next) // Used for pop when next=pop
    | includeRule(str include);

/*
    Should be used with `normalizeRules()`

    Template (testable on https://ace.c9.io/tool/mode_creator.html):
    ```js
    const oop = require("../lib/oop");
    const TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;

    const MyHighlightRules = function() {
        this.$rules = GRAMMARINPUT;
        this.normalizeRules();
    };
    oop.inherits(MyHighlightRules, TextHighlightRules);

    exports.MyHighlightRules = MyHighlightRules;
    ```
*/