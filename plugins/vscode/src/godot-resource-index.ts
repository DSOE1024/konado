export interface GodotResourceBlock {
	header: string;
	start: number;
	source: string;
	resourceKey: string;
}

export interface GodotStringValue {
	value: string;
	start: number;
	column: number;
}

export function findStringProperty(
	source: string,
	property: string,
): GodotStringValue | undefined {
	const pattern = new RegExp(`^\\s*${property}\\s*=\\s*&?"([^"]+)"`, "mu");
	const match = pattern.exec(source);
	const value = match?.[1];
	if (!match || !value) {
		return undefined;
	}
	const start = match.index + match[0].lastIndexOf(value);
	const lineStart = source.lastIndexOf("\n", start - 1) + 1;
	return { value, start, column: start - lineStart };
}

export function findScriptStringDefault(
	source: string | undefined,
	property: string,
): GodotStringValue | undefined {
	if (!source) {
		return undefined;
	}
	const pattern = new RegExp(
		`^\\s*(?:@export(?:_[A-Za-z0-9_]+)?(?:\\([^\\n]*\\))?\\s+)?var\\s+${property}\\s*(?::[^=\\n]+)?=\\s*&?"([^"]*)"`,
		"mu",
	);
	const value = pattern.exec(source)?.[1];
	return value ? { value, start: 0, column: 0 } : undefined;
}

export function collectExternalResources(source: string): Map<string, string> {
	const resources = new Map<string, string>();
	for (const match of source.matchAll(/^\[ext_resource[^\]]*\]$/gmu)) {
		const header = match[0];
		const id = headerAttribute(header, "id");
		const resourcePath = headerAttribute(header, "path");
		if (id && resourcePath) {
			resources.set(id, resourcePath);
		}
	}
	return resources;
}

export function collectResourceBlocks(
	source: string,
	resourcePath: string,
): GodotResourceBlock[] {
	const headers = [
		...source.matchAll(/^\[(?:sub_resource|resource|node)[^\]]*\]$/gmu),
	];
	return headers.map((header, index) => {
		const start = (header.index ?? 0) + header[0].length;
		const end = headers[index + 1]?.index ?? source.length;
		return {
			header: header[0],
			start,
			source: source.slice(start, end),
			resourceKey: resourceKeyForBlock(resourcePath, header[0]),
		};
	});
}

export function resolvePropertyTarget(
	source: string,
	property: string,
	resources: ReadonlyMap<string, string>,
): string | undefined {
	const pattern = new RegExp(
		`^\\s*${property}\\s*=\\s*ExtResource\\("([^"]+)"\\)`,
		"mu",
	);
	const id = pattern.exec(source)?.[1];
	return id ? resources.get(id) : undefined;
}

export function resolvePropertyResourceKey(
	source: string,
	property: string,
	resources: ReadonlyMap<string, string>,
	ownerPath: string,
): string | undefined {
	const external = resolvePropertyTarget(source, property, resources);
	if (external) {
		return external;
	}
	const pattern = new RegExp(
		`^\\s*${property}\\s*=\\s*SubResource\\("([^"]+)"\\)`,
		"mu",
	);
	const id = pattern.exec(source)?.[1];
	return id ? resourceKey(ownerPath, id) : undefined;
}

export function collectPropertyResourceKeys(
	source: string,
	property: string,
	resources: ReadonlyMap<string, string>,
	ownerPath: string,
): readonly string[] {
	const assignment = new RegExp(`^\\s*${property}\\s*=\\s*`, "mu").exec(
		source,
	);
	if (!assignment) {
		return [];
	}
	const valueStart = assignment.index + assignment[0].length;
	const remainder = source.slice(valueStart);
	const nextProperty = /\n\s*[A-Za-z_][A-Za-z0-9_/]*\s*=/u.exec(remainder);
	const value = remainder.slice(0, nextProperty?.index ?? remainder.length);
	const keys = new Set<string>();
	for (const match of value.matchAll(/ExtResource\("([^"]+)"\)/gu)) {
		const target = resources.get(match[1] ?? "");
		if (target) {
			keys.add(target);
		}
	}
	for (const match of value.matchAll(/SubResource\("([^"]+)"\)/gu)) {
		const id = match[1];
		if (id) {
			keys.add(resourceKey(ownerPath, id));
		}
	}
	return [...keys];
}

export function isFramingProfileBlock(
	block: Pick<GodotResourceBlock, "header" | "source">,
	resources: ReadonlyMap<string, string>,
): boolean {
	return (
		block.header.includes('script_class="KonadoActorFramingProfile"') ||
		resolvePropertyTarget(block.source, "script", resources)?.endsWith(
			"/konado_actor_framing_profile.gd",
		) === true
	);
}

export function resourceKey(path: string, subresourceId?: string): string {
	return subresourceId ? `${path}::${subresourceId}` : path;
}

export function addResourceDependency(
	dependencies: Map<string, Set<string>>,
	ownerKey: string,
	targetKey: string,
): void {
	if (!ownerKey || !targetKey) {
		return;
	}
	const targets = dependencies.get(ownerKey) ?? new Set<string>();
	targets.add(targetKey);
	dependencies.set(ownerKey, targets);
}

export function expandResourceKeys(
	initialKey: string,
	dependencies: ReadonlyMap<string, ReadonlySet<string>>,
): ReadonlySet<string> {
	const expanded = new Set<string>();
	const pending = initialKey ? [initialKey] : [];
	while (pending.length > 0) {
		const ownerKey = pending.pop();
		if (!ownerKey || expanded.has(ownerKey)) {
			continue;
		}
		expanded.add(ownerKey);
		for (const targetKey of dependencies.get(ownerKey) ?? []) {
			if (!expanded.has(targetKey)) {
				pending.push(targetKey);
			}
		}
	}
	return expanded;
}

function resourceKeyForBlock(path: string, header: string): string {
	return header.startsWith("[sub_resource")
		? resourceKey(path, headerAttribute(header, "id"))
		: path;
}

function headerAttribute(
	header: string,
	attribute: string,
): string | undefined {
	return new RegExp(`(?:^|\\s)${attribute}="([^"]+)"`, "u").exec(header)?.[1];
}
