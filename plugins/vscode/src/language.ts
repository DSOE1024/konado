import {
	BACKGROUND_EFFECTS,
	CAMERA_TRANSITIONS,
	CONTEXT_KEYWORDS,
	ROOT_KEYWORDS,
} from "./catalog";

export interface Token {
	text: string;
	start: number;
	end: number;
	quoted: boolean;
	closed: boolean;
}

export type SymbolKind =
	| "actors"
	| "states"
	| "motions"
	| "backgrounds"
	| "bgms"
	| "sfx"
	| "voices"
	| "cameras"
	| "branches"
	| "variables"
	| "signals"
	| "achievements"
	| "scripts";

export interface SymbolReference {
	kind: SymbolKind;
	name: string;
	line: number;
	start: number;
	end: number;
	role: "definition" | "reference";
	scopeName?: string;
}

export interface TextEditSpec {
	line: number;
	start: number;
	end: number;
	newText: string;
}

export interface QuickFixSpec {
	title: string;
	titleZh: string;
	edits: TextEditSpec[];
	preferred?: boolean;
}

export interface DiagnosticSpec {
	code: string;
	severity: "error" | "warning";
	line: number;
	start: number;
	end: number;
	message: string;
	messageZh: string;
	fixes?: QuickFixSpec[];
}

export interface IndexedDefinition {
	kind: SymbolKind;
	name: string;
	uri: string;
	line: number;
	start: number;
	end: number;
	targetUri?: string;
	scopeName?: string;
}

export interface ProjectSnapshot {
	definitions(kind: SymbolKind, name?: string): readonly IndexedDefinition[];
	values(kind: SymbolKind, scopeName?: string): readonly string[];
	hasUri(uri: string): boolean;
}

const IDENTIFIER = /^[\p{L}_][\p{L}\p{N}_-]*$/u;
const VARIABLE = /^[%$][\p{L}_][\p{L}\p{N}_]*$/u;
const NUMBER = /^[-+]?(?:\d+(?:\.\d+)?|\.\d+)$/;
const INTEGER = /^[-+]?\d+$/;
const COMPARISON = /^(?:==|!=|>=|<=|>|<)$/;
const RES_PATH = /^res:\/\/\S+\.ks$/;

const ROOT_SET = new Set<string>(ROOT_KEYWORDS);
const ACTOR_ACTIONS = new Set<string>(CONTEXT_KEYWORDS.actor);
const AUDIO_TYPES = new Set<string>(CONTEXT_KEYWORDS.play);
const CAMERA_ACTIONS = new Set<string>(CONTEXT_KEYWORDS.cam);
const ASYNC_CAMERA_ACTIONS = new Set<string>(CONTEXT_KEYWORDS.asyncam);
const ACHIEVEMENT_ACTIONS = new Set<string>(CONTEXT_KEYWORDS.achievement);
const EFFECTS = new Set<string>(BACKGROUND_EFFECTS);
const TRANSITIONS = new Set<string>(CAMERA_TRANSITIONS);

export function splitCodeAndComment(line: string): {
	code: string;
	comment: string;
	commentStart: number;
} {
	let quoted = false;
	let escaped = false;
	for (let index = 0; index < line.length; index += 1) {
		const character = line[index];
		if (escaped) {
			escaped = false;
			continue;
		}
		if (character === "\\" && quoted) {
			escaped = true;
			continue;
		}
		if (character === '"') {
			quoted = !quoted;
			continue;
		}
		if (character === "#" && !quoted) {
			return {
				code: line.slice(0, index),
				comment: line.slice(index),
				commentStart: index,
			};
		}
	}
	return { code: line, comment: "", commentStart: line.length };
}

export function tokenizeLine(line: string): Token[] {
	const { code } = splitCodeAndComment(line);
	const tokens: Token[] = [];
	let index = 0;
	while (index < code.length) {
		if (/\s/u.test(code[index] ?? "")) {
			index += 1;
			continue;
		}
		const start = index;
		if (code[index] === '"') {
			index += 1;
			let escaped = false;
			let closed = false;
			while (index < code.length) {
				const character = code[index];
				if (escaped) {
					escaped = false;
				} else if (character === "\\") {
					escaped = true;
				} else if (character === '"') {
					index += 1;
					closed = true;
					break;
				}
				index += 1;
			}
			tokens.push({
				text: code.slice(start + 1, closed ? index - 1 : index),
				start,
				end: index,
				quoted: true,
				closed,
			});
			continue;
		}
		if (code.startsWith("->", index)) {
			tokens.push({
				text: "->",
				start,
				end: index + 2,
				quoted: false,
				closed: true,
			});
			index += 2;
			continue;
		}
		while (index < code.length && !/\s/u.test(code[index] ?? "")) {
			if (code.startsWith("->", index)) {
				break;
			}
			index += 1;
		}
		tokens.push({
			text: code.slice(start, index),
			start,
			end: index,
			quoted: false,
			closed: true,
		});
	}
	return tokens;
}

function reference(
	tokens: readonly Token[],
	tokenIndex: number,
	kind: SymbolKind,
	line: number,
	role: SymbolReference["role"] = "reference",
	scopeName?: string,
): SymbolReference | undefined {
	const token = tokens[tokenIndex];
	if (!token || token.text.length === 0) {
		return undefined;
	}
	return {
		kind,
		name: token.text,
		line,
		start: token.start + (token.quoted ? 1 : 0),
		end: token.end - (token.quoted && token.closed ? 1 : 0),
		role,
		scopeName,
	};
}

function variablesInLine(line: string, lineNumber: number): SymbolReference[] {
	const results: SymbolReference[] = [];
	const { code } = splitCodeAndComment(line);
	for (const match of code.matchAll(/[%$][\p{L}_][\p{L}\p{N}_]*/gu)) {
		const start = match.index;
		const name = match[0];
		results.push({
			kind: "variables",
			name,
			line: lineNumber,
			start,
			end: start + name.length,
			role: /^(?:\s*)(?:set|add|sub|mul|div)\s/u.test(code)
				? "definition"
				: "reference",
		});
	}
	return results;
}

export function referencesForLine(
	line: string,
	lineNumber: number,
	insideScreenText = false,
): SymbolReference[] {
	const tokens = tokenizeLine(line);
	const results = variablesInLine(line, lineNumber);
	const root = tokens[0]?.text.replace(/:$/u, "");
	if (!root || insideScreenText) {
		return results;
	}
	const add = (value: SymbolReference | undefined): void => {
		if (value) {
			results.push(value);
		}
	};
	switch (root) {
		case "branch":
			add(reference(tokens, 1, "branches", lineNumber, "definition"));
			break;
		case "choice":
			add(reference(tokens, 3, "branches", lineNumber));
			break;
		case "jump_branch":
			add(reference(tokens, 1, "branches", lineNumber));
			break;
		case "jump":
			add(reference(tokens, 1, "scripts", lineNumber));
			break;
		case "background":
			add(reference(tokens, 1, "backgrounds", lineNumber));
			break;
		case "play":
			if (tokens[1]?.text === "bgm") {
				add(reference(tokens, 2, "bgms", lineNumber));
			} else if (tokens[1]?.text === "sfx") {
				add(reference(tokens, 2, "sfx", lineNumber));
			}
			break;
		case "actor": {
			const actorName = tokens[2]?.text;
			add(reference(tokens, 2, "actors", lineNumber));
			if (tokens[1]?.text === "show" || tokens[1]?.text === "change") {
				add(
					reference(
						tokens,
						3,
						"states",
						lineNumber,
						"reference",
						actorName,
					),
				);
			} else if (tokens[1]?.text === "motion") {
				add(
					reference(
						tokens,
						3,
						"motions",
						lineNumber,
						"reference",
						actorName,
					),
				);
			}
			break;
		}
		case "cam":
		case "asyncam":
			if (tokens[1]?.text === "move") {
				add(reference(tokens, 2, "cameras", lineNumber));
			}
			break;
		case "signal":
			add(reference(tokens, 1, "signals", lineNumber, "definition"));
			break;
		case "waitsignal":
			add(reference(tokens, 1, "signals", lineNumber));
			break;
		case "achievement":
			add(reference(tokens, 2, "achievements", lineNumber, "definition"));
			break;
		default:
			if (tokens[0]?.quoted) {
				add(reference(tokens, 0, "actors", lineNumber));
				if (tokens.length >= 3) {
					add(reference(tokens, 2, "voices", lineNumber));
				}
			}
	}
	return deduplicateReferences(results);
}

export function extractReferences(source: string): SymbolReference[] {
	const results: SymbolReference[] = [];
	let insideScreenText = false;
	source.split(/\r?\n/u).forEach((line, lineNumber) => {
		const tokens = tokenizeLine(line);
		const content = splitCodeAndComment(line).code.trim();
		results.push(...referencesForLine(line, lineNumber, insideScreenText));
		if (
			!insideScreenText &&
			tokens[0]?.text === "screentext" &&
			content.endsWith("{")
		) {
			insideScreenText = true;
		} else if (insideScreenText && content === "}") {
			insideScreenText = false;
		}
	});
	return results;
}

function deduplicateReferences(
	references: SymbolReference[],
): SymbolReference[] {
	const seen = new Set<string>();
	return references.filter((item) => {
		const key = `${item.kind}:${item.line}:${item.start}:${item.end}`;
		if (seen.has(key)) {
			return false;
		}
		seen.add(key);
		return true;
	});
}

function diagnostic(
	line: number,
	token: Token | undefined,
	code: string,
	message: string,
	messageZh: string,
	fixes?: QuickFixSpec[],
): DiagnosticSpec {
	return {
		code,
		severity: "error",
		line,
		start: token?.start ?? 0,
		end: Math.max(token?.end ?? 1, (token?.start ?? 0) + 1),
		message,
		messageZh,
		fixes,
	};
}

function replaceTokenFix(
	line: number,
	token: Token,
	replacement: string,
	title: string,
	titleZh: string,
): QuickFixSpec {
	return {
		title,
		titleZh,
		preferred: true,
		edits: [
			{ line, start: token.start, end: token.end, newText: replacement },
		],
	};
}

function closestValues(
	value: string,
	candidates: readonly string[],
	maximum = 3,
): string[] {
	return [...candidates]
		.map((candidate) => ({
			candidate,
			distance: editDistance(value, candidate),
		}))
		.filter(
			({ distance }) =>
				distance <= Math.max(2, Math.floor(value.length / 2)),
		)
		.sort(
			(left, right) =>
				left.distance - right.distance ||
				left.candidate.localeCompare(right.candidate),
		)
		.slice(0, maximum)
		.map(({ candidate }) => candidate);
}

export function editDistance(left: string, right: string): number {
	const previous = Array.from(
		{ length: right.length + 1 },
		(_, index) => index,
	);
	for (let leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
		const current = [leftIndex];
		for (let rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
			current[rightIndex] = Math.min(
				(current[rightIndex - 1] ?? 0) + 1,
				(previous[rightIndex] ?? 0) + 1,
				(previous[rightIndex - 1] ?? 0) +
					(left[leftIndex - 1] === right[rightIndex - 1] ? 0 : 1),
			);
		}
		previous.splice(0, previous.length, ...current);
	}
	return previous[right.length] ?? 0;
}

function requireCount(
	diagnostics: DiagnosticSpec[],
	line: number,
	tokens: readonly Token[],
	expected: number,
	signature: string,
): boolean {
	if (tokens.length === expected) {
		return true;
	}
	const token = tokens[Math.min(tokens.length - 1, expected)] ?? tokens[0];
	diagnostics.push(
		diagnostic(
			line,
			token,
			"syntax.arguments",
			`Expected: ${signature}`,
			`应为：${signature}`,
		),
	);
	return false;
}

function validateCommand(
	line: number,
	content: string,
	tokens: readonly Token[],
	diagnostics: DiagnosticSpec[],
): void {
	const root = tokens[0]?.text.replace(/:$/u, "") ?? "";
	if (!ROOT_SET.has(root)) {
		const token = tokens[0];
		const fixes = token
			? closestValues(root, ROOT_KEYWORDS).map((candidate) =>
					replaceTokenFix(
						line,
						token,
						candidate,
						`Replace with '${candidate}'`,
						`替换为“${candidate}”`,
					),
				)
			: undefined;
		diagnostics.push(
			diagnostic(
				line,
				token,
				"syntax.unrecognized",
				`Unrecognized syntax: ${root}`,
				`无法识别的语法：${root}`,
				fixes,
			),
		);
		return;
	}

	switch (root) {
		case "screentext":
			if (tokens.length !== 2 || tokens[1]?.text !== "{") {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1] ?? tokens[0],
						"syntax.screentext_open",
						"A screen-text block must start with 'screentext {'.",
						"全屏文本块必须以“screentext {”开始。",
					),
				);
			}
			break;
		case "showtextbox":
		case "hidetextbox":
			if (
				tokens.length > 2 ||
				(tokens[1] && !NUMBER.test(tokens[1].text))
			) {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1] ?? tokens[0],
						"syntax.duration",
						`${root} accepts one optional non-negative duration.`,
						`${root} 只接受一个可选的非负动画时长。`,
					),
				);
			} else if (tokens[1] && Number(tokens[1].text) < 0) {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1],
						"syntax.duration",
						"Duration cannot be negative.",
						"动画时长不能为负数。",
					),
				);
			}
			break;
		case "waitsignal":
		case "signal":
		case "jump_branch":
		case "branch":
			requireCount(diagnostics, line, tokens, 2, `${root} <name>`);
			break;
		case "jump":
			if (
				requireCount(
					diagnostics,
					line,
					tokens,
					2,
					"jump <res://path/to/script.ks>",
				)
			) {
				const path = tokens[1];
				if (path && !RES_PATH.test(path.text)) {
					diagnostics.push(
						diagnostic(
							line,
							path,
							"syntax.jump_path",
							"Jump target must be an exported res:// KonadoScript path.",
							"跳转目标必须是会被导出的 res:// KonadoScript 路径。",
						),
					);
				}
			}
			break;
		case "background":
			if (tokens.length < 2 || tokens.length > 3) {
				requireCount(
					diagnostics,
					line,
					tokens,
					2,
					"background <background_name> [transition]",
				);
			} else if (tokens[2] && !EFFECTS.has(tokens[2].text)) {
				const token = tokens[2];
				diagnostics.push(
					diagnostic(
						line,
						token,
						"syntax.background_effect",
						`Unknown background transition '${token.text}'.`,
						`未知的背景转场“${token.text}”。`,
						closestValues(token.text, BACKGROUND_EFFECTS).map(
							(candidate) =>
								replaceTokenFix(
									line,
									token,
									candidate,
									`Replace with '${candidate}'`,
									`替换为“${candidate}”`,
								),
						),
					),
				);
			}
			break;
		case "actor":
			validateActor(line, tokens, diagnostics);
			break;
		case "play":
			if (
				!requireCount(
					diagnostics,
					line,
					tokens,
					3,
					"play <bgm|sfx> <resource_name>",
				)
			) {
				break;
			}
			if (tokens[1] && !AUDIO_TYPES.has(tokens[1].text)) {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1],
						"syntax.audio_type",
						"Audio type must be 'bgm' or 'sfx'.",
						"音频类型必须为“bgm”或“sfx”。",
					),
				);
			}
			break;
		case "stop":
			if (tokens.length > 2 || (tokens[1] && tokens[1].text !== "bgm")) {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1],
						"syntax.stop",
						"Expected: stop bgm",
						"应为：stop bgm",
					),
				);
			}
			break;
		case "choice":
			if (
				tokens.length !== 4 ||
				!tokens[1]?.quoted ||
				tokens[2]?.text !== "->" ||
				!IDENTIFIER.test(tokens[3]?.text ?? "")
			) {
				const fixes: QuickFixSpec[] = [];
				if (tokens.length === 3 && tokens[1]?.quoted && tokens[2]) {
					fixes.push({
						title: "Insert missing '->'",
						titleZh: "补充缺失的“->”",
						preferred: true,
						edits: [
							{
								line,
								start: tokens[2].start,
								end: tokens[2].start,
								newText: "-> ",
							},
						],
					});
				}
				diagnostics.push(
					diagnostic(
						line,
						tokens.at(-1),
						"syntax.choice",
						'Expected: choice "<option>" -> <branch_name>',
						'应为：choice "<选项>" -> <分支名>',
						fixes,
					),
				);
			}
			break;
		case "if":
			validateIf(line, content, tokens, diagnostics);
			break;
		case "else":
			if (content !== "else:") {
				diagnostics.push(
					diagnostic(
						line,
						tokens[0],
						"syntax.else",
						"Expected: else:",
						"应为：else:",
						[
							{
								title: "Replace with 'else:'",
								titleZh: "替换为“else:”",
								preferred: true,
								edits: [
									{
										line,
										start: 0,
										end: content.length,
										newText: "else:",
									},
								],
							},
						],
					),
				);
			}
			break;
		case "endif":
		case "end":
			if (tokens.length !== 1) {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1],
						`syntax.${root}`,
						`Expected: ${root}`,
						`应为：${root}`,
						[
							{
								title: `Replace with '${root}'`,
								titleZh: `替换为“${root}”`,
								preferred: true,
								edits: [
									{
										line,
										start: 0,
										end: content.length,
										newText: root,
									},
								],
							},
						],
					),
				);
			}
			break;
		case "set":
			if (
				tokens.length < 3 ||
				tokens.length > 4 ||
				!VARIABLE.test(tokens[1]?.text ?? "") ||
				(tokens.length === 4 && tokens[2]?.text !== "=")
			) {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1] ?? tokens[0],
						"syntax.variable",
						"Expected: set <%variable|$variable> [=] <value>",
						"应为：set <%变量|$变量> [=] <值>",
					),
				);
			}
			break;
		case "add":
		case "sub":
		case "mul":
		case "div":
			if (
				!requireCount(
					diagnostics,
					line,
					tokens,
					3,
					`${root} <%variable|$variable> <value>`,
				)
			) {
				break;
			}
			if (!VARIABLE.test(tokens[1]?.text ?? "")) {
				diagnostics.push(
					diagnostic(
						line,
						tokens[1],
						"syntax.variable",
						"A variable must begin with '%' or '$'.",
						"变量必须以“%”或“$”开头。",
					),
				);
			}
			break;
		case "achievement":
			validateAchievement(line, tokens, diagnostics);
			break;
		case "cam":
		case "asyncam":
			validateCamera(line, tokens, diagnostics);
			break;
	}
}

function validateActor(
	line: number,
	tokens: readonly Token[],
	diagnostics: DiagnosticSpec[],
): void {
	const action = tokens[1];
	if (!action || !ACTOR_ACTIONS.has(action.text)) {
		const fixes = action
			? closestValues(action.text, CONTEXT_KEYWORDS.actor).map(
					(candidate) =>
						replaceTokenFix(
							line,
							action,
							candidate,
							`Replace with '${candidate}'`,
							`替换为“${candidate}”`,
						),
				)
			: undefined;
		diagnostics.push(
			diagnostic(
				line,
				action,
				"syntax.actor_action",
				"Actor action must be show, exit, change, move, or motion.",
				"actor 操作必须为 show、exit、change、move 或 motion。",
				fixes,
			),
		);
		return;
	}
	const signatures: Record<string, number> = {
		exit: 3,
		change: 4,
		move: 4,
		motion: 4,
		show: 6,
	};
	if (
		!requireCount(
			diagnostics,
			line,
			tokens,
			signatures[action.text] ?? 3,
			`actor ${action.text} ...`,
		)
	) {
		return;
	}
	if (action.text === "show") {
		if (tokens[4]?.text !== "at" || !NUMBER.test(tokens[5]?.text ?? "")) {
			diagnostics.push(
				diagnostic(
					line,
					tokens[4] ?? tokens[3],
					"syntax.actor_position",
					"Expected: actor show <actor> <state> at <position>",
					"应为：actor show <角色> <状态> at <位置>",
				),
			);
		}
	} else if (action.text === "move" && !NUMBER.test(tokens[3]?.text ?? "")) {
		diagnostics.push(
			diagnostic(
				line,
				tokens[3],
				"syntax.actor_position",
				"Actor position must be numeric.",
				"演员位置必须是数字。",
			),
		);
	}
}

function validateIf(
	line: number,
	content: string,
	tokens: readonly Token[],
	diagnostics: DiagnosticSpec[],
): void {
	if (!content.endsWith(":")) {
		diagnostics.push(
			diagnostic(
				line,
				tokens.at(-1),
				"syntax.if_colon",
				"A conditional line must end with ':'.",
				"条件语句必须以“:”结尾。",
				[
					{
						title: "Add missing ':'",
						titleZh: "补充缺失的“:”",
						preferred: true,
						edits: [
							{
								line,
								start: content.length,
								end: content.length,
								newText: ":",
							},
						],
					},
				],
			),
		);
	}
	const normalizedLast = tokens.at(-1)?.text.replace(/:$/u, "") ?? "";
	if (
		tokens.length !== 4 ||
		!VARIABLE.test(tokens[1]?.text ?? "") ||
		!COMPARISON.test(tokens[2]?.text ?? "") ||
		!INTEGER.test(normalizedLast)
	) {
		const fixes: QuickFixSpec[] = [];
		const operator = tokens[2];
		if (operator?.text === "=") {
			fixes.push(
				replaceTokenFix(
					line,
					operator,
					"==",
					"Replace '=' with '=='",
					"将“=”替换为“==”",
				),
			);
		}
		diagnostics.push(
			diagnostic(
				line,
				tokens[1] ?? tokens[0],
				"syntax.condition",
				"Expected: if <%variable|$variable> <operator> <integer>:",
				"应为：if <%变量|$变量> <比较运算符> <整数>:",
				fixes,
			),
		);
	}
}

function validateAchievement(
	line: number,
	tokens: readonly Token[],
	diagnostics: DiagnosticSpec[],
): void {
	const action = tokens[1];
	if (!action || !ACHIEVEMENT_ACTIONS.has(action.text)) {
		diagnostics.push(
			diagnostic(
				line,
				action,
				"syntax.achievement_action",
				"Achievement action must be unlock, increment, or set_flag.",
				"achievement 操作必须为 unlock、increment 或 set_flag。",
			),
		);
		return;
	}
	const expected = action.text === "unlock" ? 3 : 4;
	if (
		!requireCount(
			diagnostics,
			line,
			tokens,
			expected,
			`achievement ${action.text} ...`,
		)
	) {
		return;
	}
	if (!tokens[2]?.quoted) {
		diagnostics.push(
			diagnostic(
				line,
				tokens[2],
				"syntax.achievement_id",
				"Achievement and flag IDs must be quoted.",
				"成就与标记 ID 必须使用引号。",
			),
		);
	}
	if (action.text === "increment" && !NUMBER.test(tokens[3]?.text ?? "")) {
		diagnostics.push(
			diagnostic(
				line,
				tokens[3],
				"syntax.achievement_amount",
				"Achievement increment must be numeric.",
				"成就增量必须是数字。",
			),
		);
	}
	if (
		action.text === "set_flag" &&
		!["true", "false"].includes(tokens[3]?.text ?? "")
	) {
		const value = tokens[3];
		diagnostics.push(
			diagnostic(
				line,
				value,
				"syntax.boolean",
				"Flag value must be true or false.",
				"标记值必须为 true 或 false。",
				value
					? ["true", "false"].map((candidate) =>
							replaceTokenFix(
								line,
								value,
								candidate,
								`Replace with '${candidate}'`,
								`替换为“${candidate}”`,
							),
						)
					: undefined,
			),
		);
	}
}

function validateCamera(
	line: number,
	tokens: readonly Token[],
	diagnostics: DiagnosticSpec[],
): void {
	const root = tokens[0]?.text ?? "cam";
	const action = tokens[1];
	const actions = root === "asyncam" ? ASYNC_CAMERA_ACTIONS : CAMERA_ACTIONS;
	if (!action || !actions.has(action.text)) {
		diagnostics.push(
			diagnostic(
				line,
				action,
				"syntax.camera_action",
				`${root} action must be ${[...actions].join(", ")}.`,
				`${root} 操作必须为 ${[...actions].join("、")}。`,
			),
		);
		return;
	}
	if (action.text === "stop") {
		requireCount(diagnostics, line, tokens, 2, "asyncam stop");
		return;
	}
	let optionStart = 2;
	if (action.text === "move") {
		if (!tokens[2]) {
			diagnostics.push(
				diagnostic(
					line,
					action,
					"syntax.camera_target",
					`${root} move requires a camera name.`,
					`${root} move 缺少目标镜头名。`,
				),
			);
			return;
		}
		optionStart = 3;
	}
	const option = tokens[optionStart];
	const duration = tokens[optionStart + 1];
	if (action.text === "shake") {
		if (option && !NUMBER.test(option.text)) {
			diagnostics.push(
				diagnostic(
					line,
					option,
					"syntax.duration",
					"Camera shake duration must be numeric.",
					"镜头震动时长必须是数字。",
				),
			);
		}
	} else {
		if (option && !TRANSITIONS.has(option.text)) {
			diagnostics.push(
				diagnostic(
					line,
					option,
					"syntax.camera_transition",
					`Unknown camera transition '${option.text}'.`,
					`未知的镜头过渡“${option.text}”。`,
				),
			);
		}
		if (duration && !NUMBER.test(duration.text)) {
			diagnostics.push(
				diagnostic(
					line,
					duration,
					"syntax.duration",
					"Camera transition duration must be numeric.",
					"镜头过渡时长必须是数字。",
				),
			);
		}
	}
	if (tokens.length > optionStart + 2) {
		diagnostics.push(
			diagnostic(
				line,
				tokens[optionStart + 2],
				"syntax.arguments",
				`${root} has too many arguments.`,
				`${root} 参数过多。`,
			),
		);
	}
}

export function analyzeDocument(
	source: string,
	project?: ProjectSnapshot,
): DiagnosticSpec[] {
	const diagnostics: DiagnosticSpec[] = [];
	const lines = source.split(/\r?\n/u);
	const ifStack: number[] = [];
	let insideScreenText = false;
	let screenStart = -1;

	lines.forEach((line, lineNumber) => {
		const { code } = splitCodeAndComment(line);
		const content = code.trim();
		if (content.length === 0) {
			return;
		}
		const tokens = tokenizeLine(line);
		const unclosedString = tokens.find(
			(token) => token.quoted && !token.closed,
		);
		if (unclosedString) {
			diagnostics.push(
				diagnostic(
					lineNumber,
					unclosedString,
					"syntax.unclosed_string",
					"String is missing a closing quote.",
					"字符串缺少结束引号。",
					[
						{
							title: "Add closing quote",
							titleZh: "补充结束引号",
							preferred: true,
							edits: [
								{
									line: lineNumber,
									start: unclosedString.end,
									end: unclosedString.end,
									newText: '"',
								},
							],
						},
					],
				),
			);
			return;
		}
		if (insideScreenText) {
			if (content === "}") {
				insideScreenText = false;
			} else if (tokens.length !== 1 || !tokens[0]?.quoted) {
				diagnostics.push(
					diagnostic(
						lineNumber,
						tokens[0],
						"syntax.screentext_content",
						"A screen-text block accepts only quoted text lines or '}'.",
						"全屏文本块内只允许带引号的文本行或“}”。",
					),
				);
			}
			return;
		}

		if (tokens[0]?.quoted) {
			if (tokens.length < 2 || !tokens[1]?.quoted || tokens.length > 3) {
				diagnostics.push(
					diagnostic(
						lineNumber,
						tokens[0],
						"syntax.dialogue",
						'Expected: "<actor>" "<dialogue>" [voice_id]',
						'应为："<角色>" "<对话>" [语音 ID]',
					),
				);
			}
			return;
		}

		validateCommand(lineNumber, content, tokens, diagnostics);
		const root = tokens[0]?.text.replace(/:$/u, "");
		if (root === "screentext" && content.endsWith("{")) {
			insideScreenText = true;
			screenStart = lineNumber;
		} else if (root === "if") {
			ifStack.push(lineNumber);
		} else if (root === "else" && ifStack.length === 0) {
			diagnostics.push(
				diagnostic(
					lineNumber,
					tokens[0],
					"syntax.unexpected_else",
					"Unexpected 'else:' without a matching 'if'.",
					"“else:”没有匹配的“if”。",
				),
			);
		} else if (root === "endif") {
			if (ifStack.length === 0) {
				diagnostics.push(
					diagnostic(
						lineNumber,
						tokens[0],
						"syntax.unexpected_endif",
						"Unexpected 'endif' without a matching 'if'.",
						"“endif”没有匹配的“if”。",
						[
							{
								title: "Remove unmatched 'endif'",
								titleZh: "移除不匹配的“endif”",
								preferred: true,
								edits: [
									{
										line: lineNumber,
										start: 0,
										end: line.length,
										newText: "",
									},
								],
							},
						],
					),
				);
			} else {
				ifStack.pop();
			}
		}
	});

	if (insideScreenText) {
		const line = Math.max(0, screenStart);
		diagnostics.push(
			diagnostic(
				line,
				undefined,
				"syntax.screentext_missing_close",
				"Screen-text block is missing '}'.",
				"全屏文本块缺少“}”。",
				[
					{
						title: "Add closing '}'",
						titleZh: "补充结束括号“}”",
						preferred: true,
						edits: [
							{
								line: lines.length - 1,
								start: lines.at(-1)?.length ?? 0,
								end: lines.at(-1)?.length ?? 0,
								newText: "\n}",
							},
						],
					},
				],
			),
		);
	}
	for (const line of ifStack) {
		diagnostics.push(
			diagnostic(
				line,
				tokenizeLine(lines[line] ?? "")[0],
				"syntax.if_missing_endif",
				"Conditional block is missing 'endif'.",
				"条件块缺少“endif”。",
				[
					{
						title: "Add closing 'endif'",
						titleZh: "补充“endif”",
						preferred: true,
						edits: [
							{
								line: lines.length - 1,
								start: lines.at(-1)?.length ?? 0,
								end: lines.at(-1)?.length ?? 0,
								newText: "\nendif",
							},
						],
					},
				],
			),
		);
	}

	appendBranchDiagnostics(source, diagnostics);
	if (project) {
		appendProjectDiagnostics(source, project, diagnostics);
	}
	return diagnostics.sort(
		(left, right) => left.line - right.line || left.start - right.start,
	);
}

function appendBranchDiagnostics(
	source: string,
	diagnostics: DiagnosticSpec[],
): void {
	const references = extractReferences(source);
	const branches = new Set(
		references
			.filter(
				(item) =>
					item.kind === "branches" && item.role === "definition",
			)
			.map((item) => item.name),
	);
	for (const item of references) {
		if (
			item.kind !== "branches" ||
			item.role !== "reference" ||
			branches.has(item.name)
		) {
			continue;
		}
		diagnostics.push({
			code: "semantic.missing_branch",
			severity: "warning",
			line: item.line,
			start: item.start,
			end: item.end,
			message: `Branch '${item.name}' is not declared in this script.`,
			messageZh: `当前剧本中未声明分支“${item.name}”。`,
			fixes: [
				{
					title: `Create branch '${item.name}'`,
					titleZh: `创建分支“${item.name}”`,
					preferred: true,
					edits: [
						{
							line: source.split(/\r?\n/u).length - 1,
							start: source.split(/\r?\n/u).at(-1)?.length ?? 0,
							end: source.split(/\r?\n/u).at(-1)?.length ?? 0,
							newText: `\n\nbranch ${item.name}\n\t`,
						},
					],
				},
			],
		});
	}
}

function appendProjectDiagnostics(
	source: string,
	project: ProjectSnapshot,
	diagnostics: DiagnosticSpec[],
): void {
	const checkedKinds = new Set<SymbolKind>([
		"actors",
		"states",
		"motions",
		"backgrounds",
		"bgms",
		"sfx",
		"voices",
		"cameras",
	]);
	for (const item of extractReferences(source)) {
		if (item.kind === "scripts") {
			if (project.definitions("scripts", item.name).length === 0) {
				diagnostics.push({
					code: "semantic.missing_script",
					severity: "warning",
					line: item.line,
					start: item.start,
					end: item.end,
					message: `Target KonadoScript '${item.name}' does not exist.`,
					messageZh: `目标 KonadoScript“${item.name}”不存在。`,
				});
			}
			continue;
		}
		if (!checkedKinds.has(item.kind)) {
			continue;
		}
		const definitions = project
			.definitions(item.kind, item.name)
			.filter((definition) => {
				if (!item.scopeName || !definition.scopeName) {
					return true;
				}
				return definition.scopeName === item.scopeName;
			});
		if (definitions.length > 0) {
			continue;
		}
		const label = kindLabel(item.kind);
		const labelZh = kindLabelZh(item.kind);
		const candidates = closestValues(
			item.name,
			project.values(item.kind, item.scopeName),
		);
		diagnostics.push({
			code: "semantic.unknown_resource",
			severity: "warning",
			line: item.line,
			start: item.start,
			end: item.end,
			message: `Unknown ${label} '${item.name}'.`,
			messageZh: `未知的${labelZh}“${item.name}”。`,
			fixes: candidates.map((candidate, index) => ({
				title: `Replace with '${candidate}'`,
				titleZh: `替换为“${candidate}”`,
				preferred: index === 0,
				edits: [
					{
						line: item.line,
						start: item.start,
						end: item.end,
						newText: candidate,
					},
				],
			})),
		});
	}
}

export function kindLabel(kind: SymbolKind): string {
	return (
		{
			actors: "actor",
			states: "actor state",
			motions: "actor motion",
			backgrounds: "background",
			bgms: "BGM",
			sfx: "sound effect",
			voices: "voice",
			cameras: "camera setup",
			branches: "branch",
			variables: "variable",
			signals: "signal",
			achievements: "achievement",
			scripts: "script",
		} satisfies Record<SymbolKind, string>
	)[kind];
}

function kindLabelZh(kind: SymbolKind): string {
	return (
		{
			actors: "角色",
			states: "角色状态",
			motions: "演员动作",
			backgrounds: "背景",
			bgms: "背景音乐",
			sfx: "音效",
			voices: "语音",
			cameras: "镜头配置",
			branches: "分支",
			variables: "变量",
			signals: "信号",
			achievements: "成就",
			scripts: "剧本",
		} satisfies Record<SymbolKind, string>
	)[kind];
}
