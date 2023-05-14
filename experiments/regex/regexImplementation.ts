type ICharRange = {from: number, to: number};
type IMatch = {type: "include", chars: ICharRange[]} | {type: "exclude", chars: ICharRange[]};

type IRegexEmpty = {type: "empty"};
type IRegexMatch = {type: "match", match: IMatch};
type IRegexConcat = {type: "concat", head: IRegex, tail: IRegex};
type IRegexAlt = {type: "alt", opt1: IRegex, opt2: IRegex};
type IRegexRepeat = {type: "repeat", exp: IRegex};
type IRegex = IRegexEmpty | IRegexMatch | IRegexConcat | IRegexAlt | IRegexRepeat;

type INFAMatch = IMatch | {type: "epsilon"};
type ITransition = {from: number, to: number, on: INFAMatch};
type ILinearNFA = {start: number, end: number, transitions: ITransition[]};

type INode = {accepting: boolean, transitions: {to: number, on: INFAMatch}[]};
type INFA = {start: number, nodes: INode[]};

// Parsing
function parseRegex(regex: string): IRegex {
    const stack = regex.split("").reverse();
    return parseAlternation(stack);
}

function peek(regex: string[]) {
    return regex[regex.length-1] ?? "";
}
function consume(regex: string[], char?: string): string {
    if(char && regex[regex.length-1] != char) throw Error("Expected "+char);
    return regex.pop() ?? "";
}
function parseAlternation(regex: string[]): IRegex {
    let exp = parseConcatenation(regex);
    while(peek(regex)=="|") {
        consume(regex,"|");
        const alt = parseConcatenation(regex);
        exp = {type: "alt", opt1: exp, opt2: alt};
    }
    return exp;
}
function parseConcatenation(regex: string[]): IRegex {
    let exp = parseRepition(regex);
    let next: IRegex;
    do {
        next = parseRepition(regex);
        if(next.type != "empty")
            exp = {type: "concat", head: exp, tail: next};
    } while(next.type != "empty")
    return exp;
}
function parseRepition(regex: string[]): IRegex {
    let exp = parseBase(regex);
    while(peek(regex)=="*") {
        consume(regex, "*");
        exp = {type: "repeat", exp};
    }
    return exp;
}
function parseBase(regex: string[]): IRegex {
    if (peek(regex) == "(") {
        consume(regex, "(")
        const out = parseAlternation(regex);
        consume(regex, ")");
        return out;
    } else if (peek(regex) == "[") {
        consume(regex, "[");
        const chars: ICharRange[] = [];
        let invert = false;
        if (peek(regex)=="^") {
            consume(regex, "^");
            invert = true;
        }
        while(peek(regex) != "]") {
            const char = consume(regex);
            if(char=="") throw Error("Unexpected end of expression");
            if(char=="-") {
                const first = chars.pop();
                if (!first) throw Error("Unexpected -");
                const {from, to} = first;
                const newTo = consume(regex);
                chars.push({from, to: newTo.charCodeAt(0)});
            } else {
                const code = char.charCodeAt(0);
                chars.push({from: code, to: code});
            }
        }
        consume(regex, "]");
        return {type: "match", match: {type: invert?"exclude":"include", chars}};
    } else if(["|","*",")",""].includes(peek(regex))) {
        return {type: "empty"};
    } else {
        const code = consume(regex).charCodeAt(0);
        return {type: "match", match: {type: "include", chars: [{from: code, to: code}]}};
    }
}

// Conversion 
function toLinearNFA(regex: IRegex, counter: {id: number} = {id: 0}): ILinearNFA {
    if (regex.type == "empty") {
        const start = counter.id++;
        const end = counter.id++;
        return {start, end, transitions: [{from: start, to: end, on: {type: "epsilon"}}]};
    }
    if (regex.type == "match") {
        const start = counter.id++;
        const end = counter.id++;
        return {start, end, transitions: [{from: start, to: end, on: regex.match}]};
    }
    if (regex.type == "concat") {
        const headNFA = toLinearNFA(regex.head, counter);
        const tailNFA = toLinearNFA(regex.tail, counter);
        return {
            start: headNFA.start,
            end: tailNFA.end,
            transitions: [
                ...headNFA.transitions,
                ...tailNFA.transitions,
                {from: headNFA.end, to: tailNFA.start, on: {type: "epsilon"}}
            ]
        }
    }
    if (regex.type == "alt") {
        const start = counter.id++;
        const end = counter.id++;
        const opt1NFA = toLinearNFA(regex.opt1, counter);
        const opt2NFA = toLinearNFA(regex.opt2, counter);
        return {
            start,
            end,
            transitions: [
                ...opt1NFA.transitions,
                ...opt2NFA.transitions,
                {from: start, to: opt1NFA.start, on: {type: "epsilon"}},
                {from: start, to: opt2NFA.start, on: {type: "epsilon"}},
                {from: opt1NFA.end, to: end, on: {type: "epsilon"}},
                {from: opt2NFA.end, to: end, on: {type: "epsilon"}}
            ]
        }
    }
    if (regex.type == "repeat") {
        const start = counter.id++;
        const end = counter.id++;
        const expNFA = toLinearNFA(regex.exp, counter);
        return {
            start,
            end,
            transitions: [
                ...expNFA.transitions,
                {from: start, to: expNFA.start, on: {type: "epsilon"}},
                {from: expNFA.end, to: expNFA.start, on: {type: "epsilon"}},
                {from: expNFA.end, to: end, on: {type: "epsilon"}},
                {from: start, to: end, on: {type: "epsilon"}}
            ]
        }
    }
    return null as never;
}

function toNFA(regex: IRegex): INFA {
    const counter = {id: 0};
    const {start, end, transitions} = toLinearNFA(regex, counter);

    const nodeCount = counter.id;
    const nodes: INode[] = new Array(nodeCount);
    for (let i=0; i<nodeCount; i++) {
        nodes[i] = {
            accepting: i == end,
            transitions: []
        }
    };

    for (let {from, to, on} of transitions)
        nodes[from].transitions.push({to, on});

    return {start, nodes};
}
    
// Execution
function match(nfa: INFA, text: string) {
    var states = new Set<number>();
    states.add(nfa.start);
    followEpsilon(nfa, states);

    for (let char of text) {
        const charCode = char.charCodeAt(0);
        let newStates = new Set<number>();
        for (let state of states) {
            for (let trans of nfa.nodes[state].transitions) {
                if (trans.on.type == "epsilon") continue; // handled in followEpsilon
                const contains = trans.on.chars.some(({from, to}) => from<=charCode && charCode<=to);
                const shouldContain = trans.on.type=="include";
                if(contains != shouldContain) continue;

                newStates.add(trans.to);
            }
        }
        followEpsilon(nfa, newStates);
        states = newStates;
    }

    let matched = false;
    for (let state of states)
        if (nfa.nodes[state].accepting) matched = true;

    return matched;
}

function followEpsilon(nfa: INFA, states: Set<number>): void {
    let added = states;
    while (added.size != 0) {
        const newAdded = new Set<number>();
        for (let state of added) {
            for (let trans of nfa.nodes[state].transitions) {
                if (trans.on.type != "epsilon") continue;
                if (states.has(trans.to)) continue;

                newAdded.add(trans.to);
                states.add(trans.to);
            }
        }

        added = newAdded;
    }
}

type IStackNode = {textIndex: number; state: number, nextTransIndex: number};
function greedyMatch(nfa: INFA, text: string): {match?: string, iterations: number} {
    const stack: IStackNode[] = [{textIndex: 0, state: nfa.start, nextTransIndex: 0}];

    let iterations = 0;
    while(stack.length > 0) {
        iterations++;

        const top = stack[stack.length-1];
        const state = nfa.nodes[top.state];
        if (state.accepting) return {iterations, match: text.substring(0, top.textIndex)};

        if(top.nextTransIndex >= state.transitions.length)
            stack.pop();
        else {
            const transition = state.transitions[top.nextTransIndex];
            if (transition.on.type=="epsilon") 
                stack.push({textIndex: top.textIndex, state: transition.to, nextTransIndex: 0}); // Danger, there could be epsilon loops, which this does not account for. We could create a NFA transformation that gets rid of these loops
            else {
                const charCode = text.charCodeAt(top.textIndex);
                const contains = transition.on.chars.some(({from, to}) => from<=charCode && charCode<=to);
                const shouldContain = transition.on.type=="include";
                if(contains == shouldContain)
                    stack.push({textIndex: top.textIndex+1, state: transition.to, nextTransIndex: 0});
            }

            top.nextTransIndex++;
        }
    }

    return {iterations};
}