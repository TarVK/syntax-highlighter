import {
    Registry,
    parseRawGrammar,
    IRawGrammar,
    IGrammar,
    IOnigLib,
} from "vscode-textmate";
import {readFileSync} from "fs";
import path from "path";
import {readFile} from "fs/promises";
import * as oniguruma from "vscode-oniguruma";

const wasmBin = readFileSync(
    path.join(__dirname, "../node_modules/vscode-oniguruma/release/onig.wasm")
).buffer;
const vscodeOnigurumaLib: Promise<IOnigLib> = oniguruma.loadWASM(wasmBin).then(() => {
    return {
        createOnigScanner(patterns) {
            return new oniguruma.OnigScanner(patterns);
        },
        createOnigString(s) {
            return new oniguruma.OnigString(s);
        },
    };
});

/**
 * Loads the grammar at the given path
 * @param path The path to load the grammar at
 * @returns The grammar if found
 */
export async function loadGrammar(path: string): Promise<IGrammar | null> {
    const data = await readFile(path);
    const rawGrammar = parseRawGrammar(data.toString(), path);

    const registry = new Registry({
        onigLib: vscodeOnigurumaLib,
        loadGrammar: async () => rawGrammar,
    });

    const name = JSON.parse(data.toString("utf8")).scopeName as string;
    const grammar = await registry.loadGrammar(name);
    return grammar;
}
