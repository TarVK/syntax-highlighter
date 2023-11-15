/** The tokenization of some input text */
export type ITokenization = IScope[];
/** The assigned scope for a single character */
export type IScope = ICategory[];
/** One of the categories in the scope  */
export type ICategory = string;
