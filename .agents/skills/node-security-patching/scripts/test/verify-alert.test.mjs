import test from "node:test";
import assert from "node:assert/strict";
import {mkdtemp, mkdir, writeFile} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {locatorVersions, nearestLockfile, parseWhyRecords, resolvedLocators, ToolError} from "../lib.mjs";
import {verify} from "../verify-alert.mjs";

const alert = {
  number: 123,
  dependency: {package: {name: "@scope/package", ecosystem: "npm"}, manifest_path: "apps/mobile/package.json"},
  security_vulnerability: {vulnerable_version_range: "<2.0.0"},
};

async function fixtureRoot() {
  const root = await mkdtemp(path.join(os.tmpdir(), "security-patcher-"));
  await mkdir(path.join(root, "apps", "mobile"), {recursive: true});
  await writeFile(path.join(root, "apps", "mobile", "yarn.lock"), "# fixture\n");
  return root;
}

test("finds the nearest lockfile for an alert manifest", async () => {
  const root = await fixtureRoot();
  assert.deepEqual(await nearestLockfile(root, "apps/mobile/package.json"), {
    projectRoot: path.join(root, "apps", "mobile"),
    lockfile: path.join(root, "apps", "mobile", "yarn.lock"),
  });
});

test("retains virtual and patched Yarn npm versions", () => {
  const records = [{value: "root@workspace:.", children: {
    "@scope/package@virtual:abc#npm:2.1.0": {value: {locator: "@scope/package@virtual:abc#npm:2.1.0"}, children: {}},
    "@scope/package@patch:npm%3A2.2.0#patch": {value: {locator: "@scope/package@patch:npm%3A2.2.0#patch"}, children: {}},
  }}];
  assert.deepEqual(locatorVersions(resolvedLocators(records, "@scope/package")), ["2.1.0", "2.2.0"]);
});

test("parses Yarn 4's single JSON why tree", () => {
  const tree = {value: "root@workspace:.", children: {"package@npm:2.0.0": {value: {locator: "package@npm:2.0.0"}, children: {}}}};
  assert.deepEqual(parseWhyRecords(JSON.stringify(tree)), [tree]);
});

test("fails verification when any resolved version is vulnerable", async () => {
  const root = await fixtureRoot();
  const runCommand = async (command, args) => {
    if (command === "yarn" && args[0] === "why") {
      return {stdout: `${JSON.stringify({value: "root@workspace:.", children: {"@scope/package@npm:1.5.0": {value: {locator: "@scope/package@npm:1.5.0"}, children: {}}}})}\n`};
    }
    return {stdout: ""};
  };
  const result = await verify(alert, root, runCommand);
  assert.equal(result.passed, false);
  assert.deepEqual(result.vulnerable, ["1.5.0"]);
});

test("passes verification when all resolved versions are outside the vulnerable range", async () => {
  const root = await fixtureRoot();
  const runCommand = async (command, args) => {
    if (command === "yarn" && args[0] === "why") {
      return {stdout: `${JSON.stringify({value: "root@workspace:.", children: {"@scope/package@npm:2.0.0": {value: {locator: "@scope/package@npm:2.0.0"}, children: {}}}})}\n`};
    }
    return {stdout: ""};
  };
  const result = await verify(alert, root, runCommand);
  assert.equal(result.passed, true);
  assert.deepEqual(result.vulnerable, []);
});

test("fails rather than passing when Yarn reports no package", async () => {
  const root = await fixtureRoot();
  const runCommand = async () => ({stdout: `${JSON.stringify({value: "root@workspace:.", children: {}})}\n`});
  await assert.rejects(() => verify(alert, root, runCommand), error => error instanceof ToolError && error.exitCode === 4);
});

test("fails when recursive Yarn why fails", async () => {
  const root = await fixtureRoot();
  const runCommand = async (command, args) => {
    if (command === "yarn" && args[0] === "why") throw new ToolError("yarn why -R failed");
    return {stdout: ""};
  };
  await assert.rejects(() => verify(alert, root, runCommand), /yarn why -R failed/);
});

test("fails when recursive Yarn why produces no output", async () => {
  const root = await fixtureRoot();
  const runCommand = async () => ({stdout: ""});
  await assert.rejects(() => verify(alert, root, runCommand), error => error instanceof ToolError && error.exitCode === 4);
});

test("fails when a resolved locator has an invalid npm version", async () => {
  const root = await fixtureRoot();
  const runCommand = async (command, args) => {
    if (command === "yarn" && args[0] === "why") {
      return {stdout: `${JSON.stringify({value: "root@workspace:.", children: {
        "@scope/package@npm:2.0.0": {value: {locator: "@scope/package@npm:2.0.0"}, children: {}},
        "@scope/package@npm:not-a-version": {value: {locator: "@scope/package@npm:not-a-version"}, children: {}},
      }})}\n`};
    }
    return {stdout: ""};
  };
  await assert.rejects(() => verify(alert, root, runCommand), /Invalid resolved npm version/);
});
