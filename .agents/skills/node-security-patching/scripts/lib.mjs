import {execFile} from "node:child_process";
import {promisify} from "node:util";
import {access} from "node:fs/promises";
import path from "node:path";

const execFileAsync = promisify(execFile);

export class ToolError extends Error {
  constructor(message, exitCode = 3) {
    super(message);
    this.exitCode = exitCode;
  }
}

export async function run(command, args, options = {}) {
  try {
    const mergedOptions = {
      maxBuffer: 20 * 1024 * 1024,
      cwd: process.env.INIT_CWD || process.cwd(),
      ...options
    };
    return await execFileAsync(command, args, mergedOptions);
  } catch (error) {
    const detail = [error.stderr, error.message].filter(Boolean).join("\n");
    throw new ToolError(`${command} ${args.join(" ")} failed${detail ? `: ${detail.trim()}` : ""}`);
  }
}

export async function repository(runCommand = run) {
  const {stdout} = await runCommand("gh", ["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]);
  const value = stdout.trim();
  if (!value) throw new ToolError("Unable to determine GitHub repository");
  return value;
}

export function parseJson(text, label) {
  try {
    return JSON.parse(text);
  } catch {
    throw new ToolError(`Invalid JSON from ${label}`, 2);
  }
}

export async function exists(file) {
  try {
    await access(file);
    return true;
  } catch {
    return false;
  }
}

export async function nearestLockfile(repositoryRoot, manifestPath) {
  const relativeManifest = manifestPath.replace(/^\/+/, "");
  let directory = path.resolve(repositoryRoot, path.dirname(relativeManifest));
  const root = path.resolve(repositoryRoot);
  if (directory !== root && !directory.startsWith(`${root}${path.sep}`)) {
    throw new ToolError(`Manifest path is outside the repository: ${manifestPath}`, 2);
  }

  while (true) {
    const lockfile = path.join(directory, "yarn.lock");
    if (await exists(lockfile)) return {projectRoot: directory, lockfile};
    if (directory === root) break;
    directory = path.dirname(directory);
  }
  throw new ToolError(`No yarn.lock found for manifest ${manifestPath}`, 4);
}

export async function gitRoot(runCommand = run) {
  const {stdout} = await runCommand("git", ["rev-parse", "--show-toplevel"]);
  return stdout.trim();
}

export function parseWhyRecords(output) {
  const text = output.trim();
  if (!text) throw new ToolError("yarn why produced no JSON records", 4);
  const records = text.startsWith("{") && text.endsWith("}")
    ? [parseJson(text, "yarn why output")]
    : text.split("\n").filter(Boolean).map((line, index) => parseJson(line, `yarn why record ${index + 1}`));
  if (!records.length) throw new ToolError("yarn why produced no JSON records", 4);
  return records;
}

export function resolvedLocators(records, packageName) {
  const locators = new Set();
  const visit = value => {
    if (!value || typeof value !== "object") return;
    const locator = value.locator ?? value.value?.locator;
    if (typeof locator === "string" && locator.startsWith(`${packageName}@`)) locators.add(locator);
    for (const child of Object.values(value)) visit(child);
  };
  records.forEach(visit);
  return [...locators].sort();
}

export function locatorVersions(locators) {
  const versions = new Set();
  for (const locator of locators) {
    const decoded = decodeURIComponent(locator);
    const matches = [...decoded.matchAll(/(?:^|[@#:])npm:([^#]+)/g)];
    const version = matches.at(-1)?.[1];
    if (!version) throw new ToolError(`Cannot determine npm version from locator: ${locator}`, 4);
    versions.add(version);
  }
  return [...versions].sort();
}
