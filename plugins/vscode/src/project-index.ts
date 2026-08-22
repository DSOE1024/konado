import * as path from "node:path";
import * as vscode from "vscode";
import {
	definitionHasScope,
	extractReferences,
	type IndexedDefinition,
	type ProjectSnapshot,
	type SymbolKind,
} from "./language";
import { ACTOR_FRAMINGS } from "./catalog";
import {
	addResourceDependency,
	collectExternalResources,
	collectPropertyResourceKeys,
	collectResourceBlocks,
	expandResourceKeys,
	findScriptStringDefault,
	findStringProperty,
	isFramingProfileBlock,
	resolvePropertyResourceKey,
	resolvePropertyTarget,
} from "./godot-resource-index";

const RESOURCE_SCHEMAS = {
	actors: { name: "character_id", target: "character_scene" },
	backgrounds: { name: "background_name", target: "background_scene" },
	bgms: { name: "background_music_name", target: "stream" },
	sfx: { name: "sound_effect_name", target: "stream" },
	voices: { name: "voice_name", target: "stream" },
} as const;

const SCANNED_GLOB = "**/*.{ks,tres,tscn,gd}";
const EXCLUDED_GLOB = "**/{.git,.godot,node_modules,build,dist}/**";
const MAX_RESOURCE_BYTES = 8 * 1024 * 1024;

interface InternalDefinition extends IndexedDefinition {
	targetResourcePath?: string;
	motionResourcePath?: string;
	framingProfileResourceKey?: string;
	resourceKey?: string;
}

export class ProjectIndex implements ProjectSnapshot, vscode.Disposable {
	private readonly byKind = new Map<
		SymbolKind,
		Map<string, InternalDefinition[]>
	>();
	private readonly indexedUris = new Set<string>();
	private readonly framingDependencies = new Map<string, Set<string>>();
	private readonly changeEmitter = new vscode.EventEmitter<void>();
	private readonly watchers: vscode.Disposable[] = [];
	private rebuildPromise: Promise<void> | undefined;
	private rebuildTimer: NodeJS.Timeout | undefined;

	readonly onDidChange = this.changeEmitter.event;

	constructor(private readonly output: vscode.OutputChannel) {
		const watcher = vscode.workspace.createFileSystemWatcher(SCANNED_GLOB);
		watcher.onDidCreate(() => this.scheduleRebuild());
		watcher.onDidChange(() => this.scheduleRebuild());
		watcher.onDidDelete(() => this.scheduleRebuild());
		this.watchers.push(watcher);
	}

	dispose(): void {
		if (this.rebuildTimer) {
			clearTimeout(this.rebuildTimer);
		}
		this.watchers.forEach((watcher) => watcher.dispose());
		this.changeEmitter.dispose();
	}

	definitions(kind: SymbolKind, name?: string): readonly IndexedDefinition[] {
		const values = this.byKind.get(kind);
		if (!values) {
			return [];
		}
		if (name !== undefined) {
			return values.get(name) ?? [];
		}
		return [...values.values()].flat();
	}

	values(kind: SymbolKind, scopeName?: string): readonly string[] {
		const definitions = this.byKind.get(kind);
		if (!definitions) {
			return kind === "framings" &&
				!this.hasCustomFramingProfile(scopeName)
				? ACTOR_FRAMINGS
				: [];
		}
		const values = [...definitions.entries()]
			.filter(([, items]) => {
				if (!scopeName) {
					return true;
				}
				if (kind === "framings") {
					return items.some((item) =>
						definitionHasScope(item, scopeName),
					);
				}
				return items.some(
					(item) =>
						(!item.scopeName && !item.scopeNames?.length) ||
						definitionHasScope(item, scopeName),
				);
			})
			.map(([name]) => name)
			.sort((left, right) => left.localeCompare(right));
		return kind === "framings" &&
			scopeName &&
			values.length === 0 &&
			!this.hasCustomFramingProfile(scopeName)
			? ACTOR_FRAMINGS
			: values;
	}

	private hasCustomFramingProfile(actorName?: string): boolean {
		if (!actorName) {
			return false;
		}
		return (
			this.definitions("actors", actorName) as InternalDefinition[]
		).some((actor) => Boolean(actor.framingProfileResourceKey));
	}

	hasUri(uri: string): boolean {
		return this.indexedUris.has(uri);
	}

	async rebuild(): Promise<void> {
		if (this.rebuildPromise) {
			return this.rebuildPromise;
		}
		this.rebuildPromise = this.performRebuild().finally(() => {
			this.rebuildPromise = undefined;
		});
		return this.rebuildPromise;
	}

	scheduleRebuild(): void {
		if (this.rebuildTimer) {
			clearTimeout(this.rebuildTimer);
		}
		this.rebuildTimer = setTimeout(() => {
			this.rebuildTimer = undefined;
			void this.rebuild();
		}, 250);
	}

	updateDocument(document: vscode.TextDocument): void {
		if (document.languageId !== "konadoscript") {
			return;
		}
		const uri = document.uri.toString();
		this.removeUri(uri);
		this.indexScript(document.uri, document.getText());
		this.rebuildScopes();
		this.changeEmitter.fire();
	}

	resolveResourceUri(
		documentUri: vscode.Uri,
		resourcePath: string,
	): vscode.Uri | undefined {
		if (!resourcePath.startsWith("res://")) {
			return undefined;
		}
		const folder = vscode.workspace.getWorkspaceFolder(documentUri);
		if (!folder) {
			return undefined;
		}
		return vscode.Uri.joinPath(
			folder.uri,
			resourcePath.slice("res://".length),
		);
	}

	private async performRebuild(): Promise<void> {
		const enabled = vscode.workspace
			.getConfiguration("konado")
			.get<boolean>("projectIndex.enable", true);
		this.byKind.clear();
		this.indexedUris.clear();
		this.framingDependencies.clear();
		if (!enabled || !vscode.workspace.workspaceFolders?.length) {
			this.changeEmitter.fire();
			return;
		}

		const started = Date.now();
		const uris = await vscode.workspace.findFiles(
			SCANNED_GLOB,
			EXCLUDED_GLOB,
		);
		const sources = new Map<string, string>();
		await Promise.all(
			uris.map(async (uri) => {
				try {
					const stat = await vscode.workspace.fs.stat(uri);
					if (stat.size > MAX_RESOURCE_BYTES) {
						return;
					}
					const bytes = await vscode.workspace.fs.readFile(uri);
					const source = new TextDecoder("utf-8").decode(bytes);
					sources.set(uri.toString(), source);
				} catch (error) {
					this.output.appendLine(
						`Unable to index ${uri.toString()}: ${String(error)}`,
					);
				}
			}),
		);
		for (const uri of uris) {
			const source = sources.get(uri.toString());
			if (source === undefined) {
				continue;
			}
			if (uri.path.endsWith(".ks")) {
				this.indexScript(uri, source);
			} else if (
				uri.path.endsWith(".tres") ||
				uri.path.endsWith(".tscn")
			) {
				this.indexGodotResource(uri, source, sources);
			}
		}
		for (const document of vscode.workspace.textDocuments) {
			if (document.languageId === "konadoscript" && document.isDirty) {
				this.removeUri(document.uri.toString());
				this.indexScript(document.uri, document.getText());
			}
		}
		this.rebuildScopes();
		this.output.appendLine(
			`Indexed ${uris.length} Konado project files in ${Date.now() - started} ms.`,
		);
		this.changeEmitter.fire();
	}

	private indexScript(uri: vscode.Uri, source: string): void {
		const uriText = uri.toString();
		this.indexedUris.add(uriText);
		this.add({
			kind: "scripts",
			name: this.toResourcePath(uri),
			uri: uriText,
			line: 0,
			start: 0,
			end: 1,
			targetUri: uriText,
		});
		for (const item of extractReferences(source)) {
			if (
				item.role !== "definition" &&
				item.kind !== "variables" &&
				item.kind !== "achievements"
			) {
				continue;
			}
			this.add({
				kind: item.kind,
				name: item.name,
				uri: uriText,
				line: item.line,
				start: item.start,
				end: item.end,
				targetUri: uriText,
			});
		}
	}

	private indexGodotResource(
		uri: vscode.Uri,
		source: string,
		sources: ReadonlyMap<string, string>,
	): void {
		const uriText = uri.toString();
		// res:// paths are only unique inside one Godot project. Use the owning
		// file URI for framing graph keys so multi-root workspaces cannot leak
		// presets between projects that happen to share the same relative paths.
		const resourceOwnerKey = uriText;
		this.indexedUris.add(uriText);
		const externalResources = collectExternalResources(source);
		const blocks = collectResourceBlocks(source, resourceOwnerKey);
		for (const block of blocks) {
			for (const [kind, schema] of Object.entries(RESOURCE_SCHEMAS) as [
				keyof typeof RESOURCE_SCHEMAS,
				(typeof RESOURCE_SCHEMAS)[keyof typeof RESOURCE_SCHEMAS],
			][]) {
				const name = findStringProperty(block.source, schema.name);
				if (!name) {
					continue;
				}
				const targetResourcePath = resolvePropertyTarget(
					block.source,
					schema.target,
					externalResources,
				);
				const motionResourcePath =
					kind === "actors"
						? resolvePropertyTarget(
								block.source,
								"actor_motion_layer",
								externalResources,
							)
						: undefined;
				const framingProfileKey =
					kind === "actors"
						? resolvePropertyResourceKey(
								block.source,
								"actor_framing_profile",
								externalResources,
								resourceOwnerKey,
							)
						: undefined;
				const framingProfileResourceKey = framingProfileKey
					? this.normalizeResourceKey(uri, framingProfileKey)
					: undefined;
				this.add({
					kind,
					name: name.value,
					uri: uriText,
					line: lineAt(source, block.start + name.start),
					start: name.column,
					end: name.column + name.value.length,
					targetUri: targetResourcePath
						? this.resolveResourceUri(
								uri,
								targetResourcePath,
							)?.toString()
						: undefined,
					targetResourcePath,
					motionResourcePath,
					framingProfileResourceKey,
				});
			}

			const scriptPath = resolvePropertyTarget(
				block.source,
				"script",
				externalResources,
			);
			const scriptSource = scriptPath
				? sources.get(
						this.resolveResourceUri(uri, scriptPath)?.toString() ??
							"",
					)
				: undefined;
			const state =
				findStringProperty(block.source, "status_name") ??
				findScriptStringDefault(scriptSource, "status_name");
			if (state) {
				this.add({
					kind: "states",
					name: state.value,
					uri: uriText,
					line: lineAt(source, block.start + state.start),
					start: state.column,
					end: state.column + state.value.length,
					targetUri: uriText,
				});
			}
			const framing =
				findStringProperty(block.source, "preset_id") ??
				findScriptStringDefault(scriptSource, "preset_id");
			if (framing) {
				this.add({
					kind: "framings",
					name: framing.value,
					uri: uriText,
					line: lineAt(source, block.start + framing.start),
					start: framing.column,
					end: framing.column + framing.value.length,
					targetUri: uriText,
					resourceKey: block.resourceKey,
				});
			}
			if (isFramingProfileBlock(block, externalResources)) {
				const targetKeys = collectPropertyResourceKeys(
					block.source,
					"presets",
					externalResources,
					resourceOwnerKey,
				);
				for (const targetKey of targetKeys) {
					addResourceDependency(
						this.framingDependencies,
						block.resourceKey,
						this.normalizeResourceKey(uri, targetKey),
					);
				}
			}
			const camera =
				findStringProperty(block.source, "camera_setup") ??
				findScriptStringDefault(scriptSource, "camera_setup");
			if (camera) {
				this.add({
					kind: "cameras",
					name: camera.value,
					uri: uriText,
					line: lineAt(source, block.start + camera.start),
					start: camera.column,
					end: camera.column + camera.value.length,
					targetUri: uriText,
				});
			}
		}

		if (uri.path.endsWith(".tscn")) {
			this.collectPatternDefinitions(
				uri,
				source,
				"states",
				/"name"\s*:\s*&?"([^"]+)"/gu,
			);
			this.collectPatternDefinitions(
				uri,
				source,
				"motions",
				/^\s*resource_name\s*=\s*"([^"]+)"/gmu,
			);
		}
	}

	private collectPatternDefinitions(
		uri: vscode.Uri,
		source: string,
		kind: SymbolKind,
		pattern: RegExp,
	): void {
		for (const match of source.matchAll(pattern)) {
			const name = match[1];
			if (!name) {
				continue;
			}
			const offset = (match.index ?? 0) + match[0].indexOf(name);
			const line = lineAt(source, offset);
			const lineStart = source.lastIndexOf("\n", offset - 1) + 1;
			this.add({
				kind,
				name,
				uri: uri.toString(),
				line,
				start: offset - lineStart,
				end: offset - lineStart + name.length,
				targetUri: uri.toString(),
			});
		}
	}

	private rebuildScopes(): void {
		const actors = this.definitions("actors") as InternalDefinition[];
		const actorByTarget = new Map<string, Set<string>>();
		const actorByMotion = new Map<string, Set<string>>();
		const actorByFraming = new Map<string, Set<string>>();
		for (const actor of actors) {
			if (actor.targetResourcePath) {
				addResourceOwner(
					actorByTarget,
					this.resolveResourceUri(
						vscode.Uri.parse(actor.uri),
						actor.targetResourcePath,
					)?.toString() ?? "",
					actor.name,
				);
			}
			if (actor.motionResourcePath) {
				addResourceOwner(
					actorByMotion,
					this.resolveResourceUri(
						vscode.Uri.parse(actor.uri),
						actor.motionResourcePath,
					)?.toString() ?? "",
					actor.name,
				);
			}
			if (actor.framingProfileResourceKey) {
				for (const resourceKey of expandResourceKeys(
					actor.framingProfileResourceKey,
					this.framingDependencies,
				)) {
					addResourceOwner(actorByFraming, resourceKey, actor.name);
				}
			}
		}
		for (const definition of this.definitions(
			"states",
		) as InternalDefinition[]) {
			assignDefinitionOwners(
				definition,
				actorByTarget.get(definition.uri),
			);
		}
		for (const definition of this.definitions(
			"motions",
		) as InternalDefinition[]) {
			assignDefinitionOwners(
				definition,
				actorByMotion.get(definition.uri),
			);
		}
		for (const definition of this.definitions(
			"framings",
		) as InternalDefinition[]) {
			assignDefinitionOwners(
				definition,
				actorByFraming.get(definition.resourceKey ?? ""),
			);
		}
	}

	private add(definition: InternalDefinition): void {
		let names = this.byKind.get(definition.kind);
		if (!names) {
			names = new Map();
			this.byKind.set(definition.kind, names);
		}
		const definitions = names.get(definition.name) ?? [];
		if (
			definitions.some(
				(item) =>
					item.uri === definition.uri &&
					item.line === definition.line &&
					item.start === definition.start,
			)
		) {
			return;
		}
		definitions.push(definition);
		names.set(definition.name, definitions);
	}

	private removeUri(uri: string): void {
		for (const names of this.byKind.values()) {
			for (const [name, definitions] of names) {
				const remaining = definitions.filter(
					(definition) => definition.uri !== uri,
				);
				if (remaining.length === 0) {
					names.delete(name);
				} else {
					names.set(name, remaining);
				}
			}
		}
		this.indexedUris.delete(uri);
	}

	private toResourcePath(uri: vscode.Uri): string {
		const folder = vscode.workspace.getWorkspaceFolder(uri);
		if (!folder) {
			return uri.path;
		}
		const relative = path.posix.relative(folder.uri.path, uri.path);
		return `res://${relative}`;
	}

	private normalizeResourceKey(uri: vscode.Uri, key: string): string {
		if (!key.startsWith("res://")) {
			return key;
		}
		return this.resolveResourceUri(uri, key)?.toString() ?? key;
	}
}

function addResourceOwner(
	owners: Map<string, Set<string>>,
	resourceUri: string,
	actorName: string,
): void {
	if (!resourceUri) {
		return;
	}
	const names = owners.get(resourceUri) ?? new Set<string>();
	names.add(actorName);
	owners.set(resourceUri, names);
}

function assignDefinitionOwners(
	definition: InternalDefinition,
	owners?: ReadonlySet<string>,
): void {
	if (!owners?.size) {
		definition.scopeName = undefined;
		definition.scopeNames = undefined;
		return;
	}
	const names = [...owners].sort((left, right) => left.localeCompare(right));
	definition.scopeName = names[0];
	definition.scopeNames = names;
}

function lineAt(source: string, offset: number): number {
	return source.slice(0, Math.max(0, offset)).split("\n").length - 1;
}
