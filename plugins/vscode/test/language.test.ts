import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import {
	analyzeDocument,
	editDistance,
	extractReferences,
	referencesForLine,
	tokenizeLine,
} from "../src/language";

describe("KonadoScript tokenizer", () => {
	it("keeps comments inside strings and strips actual comments", () => {
		const tokens = tokenizeLine('"Kona" "value #1" voice_01 # comment');

		expect(tokens.map((token) => token.text)).toEqual([
			"Kona",
			"value #1",
			"voice_01",
		]);
	});

	it("reports whether a quoted token is closed", () => {
		expect(tokenizeLine('"closed"')[0]?.closed).toBe(true);
		expect(tokenizeLine('"open')[0]?.closed).toBe(false);
	});
});

describe("KonadoScript semantic references", () => {
	it("does not classify screen text as an actor", () => {
		expect(referencesForLine('    "Full-screen text"', 2, true)).toEqual(
			[],
		);
	});

	it("extracts variables embedded in dialogue strings", () => {
		const references = extractReferences(
			'"Kona" "Round=$round, reward=$bonus and love=%love"',
		);

		expect(
			references
				.filter((reference) => reference.kind === "variables")
				.map((reference) => reference.name),
		).toEqual(["$round", "$bonus", "%love"]);
	});

	it("extracts actor state scope and branch roles", () => {
		const references = extractReferences(
			[
				"actor show Kona normal at 3",
				'choice "Continue" -> next',
				"branch next",
			].join("\n"),
		);

		expect(references).toEqual(
			expect.arrayContaining([
				expect.objectContaining({ kind: "actors", name: "Kona" }),
				expect.objectContaining({
					kind: "states",
					name: "normal",
					scopeName: "Kona",
				}),
				expect.objectContaining({
					kind: "branches",
					name: "next",
					role: "reference",
				}),
				expect.objectContaining({
					kind: "branches",
					name: "next",
					role: "definition",
				}),
			]),
		);
	});
});

describe("KonadoScript diagnostics", () => {
	it("accepts every bundled sample script", () => {
		const sampleRoot = resolve(process.cwd(), "../../sample");
		const scripts = readdirSync(sampleRoot, {
			recursive: true,
			withFileTypes: true,
		}).filter((entry) => entry.isFile() && entry.name.endsWith(".ks"));

		const failures = scripts.flatMap((entry) => {
			const filePath = `${entry.parentPath}/${entry.name}`;
			return analyzeDocument(readFileSync(filePath, "utf8"))
				.filter((diagnostic) => diagnostic.severity === "error")
				.map(
					(diagnostic) =>
						`${filePath}:${diagnostic.line + 1} ${diagnostic.message}`,
				);
		});

		expect(failures).toEqual([]);
	});

	it("accepts representative valid syntax", () => {
		const source = [
			"screentext {",
			'\t"Full-screen text with $score"',
			"}",
			"background bg_end fade",
			"actor show Kona normal at 3",
			'"Kona" "Hello, %player_name!" voice_01',
			"if %love == 0:",
			'\t"Kona" "Hello"',
			"else:",
			'\t"Kona" "Again"',
			"endif",
			'choice "Leave" -> exit_choice',
			"branch exit_choice",
			"\tend",
		].join("\n");

		expect(analyzeDocument(source)).toEqual([]);
	});

	it("offers ranked fixes for misspelled commands", () => {
		const diagnostics = analyzeDocument("endif_typo");

		expect(diagnostics[0]).toMatchObject({
			code: "syntax.unrecognized",
			severity: "error",
		});
		expect(diagnostics[0]?.fixes?.length).toBeLessThanOrEqual(3);
	});

	it("detects missing conditional and screen-text terminators", () => {
		const diagnostics = analyzeDocument(
			'if %love == 0:\n\tscreentext {\n\t\t"Text"',
		);
		const codes = diagnostics.map((diagnostic) => diagnostic.code);

		expect(codes).toContain("syntax.if_missing_endif");
		expect(codes).toContain("syntax.screentext_missing_close");
	});

	it("offers a branch creation fix", () => {
		const diagnostic = analyzeDocument('choice "Continue" -> missing').find(
			(item) => item.code === "semantic.missing_branch",
		);

		expect(diagnostic?.fixes?.[0]?.edits[0]?.newText).toContain(
			"branch missing",
		);
	});
});

describe("edit distance", () => {
	it("ranks nearby command spellings", () => {
		expect(editDistance("bakground", "background")).toBe(1);
	});
});
