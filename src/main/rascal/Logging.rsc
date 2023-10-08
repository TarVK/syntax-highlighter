module Logging

import IO;

alias Logger = void(LogType logType, value val);
data LogType 
    /* Error messages*/
    = Error()
    /* General warnings */
    | Warning()
    /* Debug messages, used during development */
    | Debug()
    /* A message of what part of the algorithm we're on */
    | Section()
    /* Some progress messages per section */
    | Progress()
    /* Some detailed progress messages per production/transformation */
    | ProgressDetailed();

Logger debugLogger()
    = debugLogger({});
Logger debugLogger(set[str] debugIdentifier)
    = standardLogger({Debug()}, debugIdentifier);
Logger standardLogger()
    = standardLogger(4);
Logger standardLogger(int level) 
    = standardLogger({
        *(level >= 0 ? {Error()} : {}),
        *(level >= 1 ? {Warning()} : {}),
        *(level >= 2 ? {Section()} : {}),
        *(level >= 3 ? {Progress()} : {}),
        *(level >= 4 ? {ProgressDetailed()} : {}),
        *(level >= 5 ? {Debug()} : {})
    }, {});
Logger standardLogger(set[LogType] shownTypes, set[str] debugIdentifier) 
    = void(LogType logType, value val) {
        if(logType notin shownTypes) return;

        if(logType == Section())
            println("============= <val> =============");
        else if(logType == Error())
            println("!!Error: <val>");
        else if(logType == Warning())
            println("!Warning: <val>");
        else if(logType == Progress())
            println("Progress: <val>");
        else if(logType == ProgressDetailed())
            println("\> <val>");
        else if(logType == Debug()) {
            if(<str id, rest> := val) {
                if(id in debugIdentifier || debugIdentifier=={})
                    val = rest;
                else return;
            }

            println("<val>");
        }
    };