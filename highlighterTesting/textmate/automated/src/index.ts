import {program} from "commander";
import {loadGrammar} from "./loadGrammar";
import {tokenize} from "./linearTokenize";
import {readFile, writeFile} from "fs/promises";
import path from "path";

program
    .name("TextMate Tokenize")
    .description("Performs tokenization according to the given grammar")
    .argument("<grammarPath>", "The path to the grammar to use for tokenization")
    .argument("<inputPaths...>", "The paths to the input texts to be tokenized")
    .action(async (grammarPath: string, inputPaths: string[]) => {
        const grammar = await loadGrammar(grammarPath);
        if (grammar) {
            for (const inputPath of inputPaths) {
                const text = await readFile(inputPath, "utf-8");
                const tokenization = tokenize(grammar, text);
                const outputPath = path.format({
                    ...path.parse(inputPath),
                    base: "",
                    ext: ".tokens.json",
                });
                await writeFile(outputPath, JSON.stringify(tokenization));
            }
        }
    });

program.parse();
