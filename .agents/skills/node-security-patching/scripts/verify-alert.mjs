#!/usr/bin/env node
import semver from "semver";
import {gitRoot, locatorVersions, nearestLockfile, parseJson, parseWhyRecords, repository, resolvedLocators, run, ToolError} from "./lib.mjs";

function alertNumber(argv) {
  const index = argv.indexOf("--alert");
  const value = index === -1 ? undefined : argv[index + 1];
  if (!value || !/^\d+$/.test(value)) throw new ToolError("Usage: verify-alert.mjs --alert <number>", 2);
  return value;
}

function repositoryRoot(argv) {
  const index = argv.indexOf("--repo-root");
  const value = index === -1 ? undefined : argv[index + 1];
  if (index !== -1 && !value) throw new ToolError("Usage: verify-alert.mjs --alert <number> [--repo-root <path>]", 2);
  return value;
}

function repositoryName(argv) {
  const index = argv.indexOf("--repo");
  const value = index === -1 ? undefined : argv[index + 1];
  if (index !== -1 && !value) throw new ToolError("Usage: verify-alert.mjs --alert <number> [--repo <owner/name>] [--repo-root <path>]", 2);
  return value;
}

export async function verify(alert, repositoryRoot, runCommand = run) {
  const packageName = alert.dependency?.package?.name;
  const manifestPath = alert.dependency?.manifest_path;
  const range = alert.security_vulnerability?.vulnerable_version_range;
  if (alert.dependency?.package?.ecosystem !== "npm" || !packageName || !manifestPath || !range) {
    throw new ToolError("Alert lacks required npm package, manifest path, or vulnerable range", 2);
  }
  const {projectRoot, lockfile} = await nearestLockfile(repositoryRoot, manifestPath);
  await runCommand("yarn", ["install", "--immutable"], {cwd: projectRoot});
  const {stdout} = await runCommand("yarn", ["why", "-R", "--json", packageName], {cwd: projectRoot});
  const locators = resolvedLocators(parseWhyRecords(stdout), packageName);
  const versions = locatorVersions(locators);
  if (!versions.length) throw new ToolError(`No resolved npm versions found for ${packageName}`, 4);
  const invalidVersion = versions.find(version => !semver.valid(version));
  if (invalidVersion) throw new ToolError(`Invalid resolved npm version for ${packageName}: ${invalidVersion}`, 4);
  const vulnerable = versions.filter(version => semver.satisfies(version, range));
  return {
    alert: alert.number,
    projectRoot,
    lockfile,
    package: packageName,
    range,
    locators,
    versions,
    vulnerable,
    passed: vulnerable.length === 0,
  };
}

async function main() {
  const argv = process.argv.slice(2);
  const number = alertNumber(argv);
  const repo = repositoryName(argv) ?? await repository();
  const root = repositoryRoot(argv) ?? await gitRoot();
  const {stdout} = await run("gh", ["api", `repos/${repo}/dependabot/alerts/${number}`]);
  const result = await verify(parseJson(stdout, `Dependabot alert ${number}`), root);
  console.log(JSON.stringify(result, null, 2));
  if (!result.passed) process.exit(1);
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  main().catch(error => {
    console.error(error.message);
    process.exit(error.exitCode ?? 3);
  });
}
