import {INITIAL, IGrammar} from "vscode-textmate";
import {ITokenization} from "./_types/ITokenization";

/**
 * Creates a tokenization of the given string
 * @param grammar The grammar to use for the tokenization
 * @param input The input to be tokenized
 * @returns The tokenization
 */
export function tokenize(grammar: IGrammar, input: string): ITokenization {
    const lines: string[] = [""];
    for (let i = 0; i < input.length; i++) {
        const char = input[i];
        lines[lines.length - 1] += char;
        if (char == "\n") lines.push("");
    }

    const tokenization: ITokenization = [];

    let ruleStack = INITIAL;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const lineData = grammar.tokenizeLine(line, ruleStack);
        for (let token of lineData.tokens) {
            const scope = token.scopes.slice(1);
            for (let j = token.startIndex; j < token.endIndex; j++)
                tokenization.push(scope);
        }
        ruleStack = lineData.ruleStack;
    }

    return tokenization;
}
