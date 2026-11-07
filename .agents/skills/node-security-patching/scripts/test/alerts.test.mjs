import test from "node:test";
import assert from "node:assert/strict";
import {inventory} from "../alerts.mjs";

const alert = (number, overrides = {}) => ({
  number,
  dependency: {package: {name: "braces", ecosystem: "npm"}, manifest_path: "native/package.json", relationship: "indirect", scope: "runtime"},
  security_advisory: {severity: "high", cve_id: "CVE-2026-1", ghsa_id: "GHSA-test"},
  security_vulnerability: {vulnerable_version_range: "<3.0.3", first_patched_version: {identifier: "3.0.3"}},
  html_url: "https://example.test/alert",
  ...overrides,
});

test("filters non-npm alerts and records selected exclusions", () => {
  const result = inventory([
    alert(3, {dependency: {package: {name: "foo", ecosystem: "maven"}, manifest_path: "api/package.json"}}),
    alert(2, {dependency: {package: {name: "bar", ecosystem: "npm"}, manifest_path: "Remix/package.json"}}),
    alert(1),
  ], {excludedProjects: ["remix"]});

  assert.deepEqual(result.included.map(value => value.number), [1]);
  assert.equal(result.excluded[0].number, 2);
  assert.match(result.excluded[0].exclusionReason, /remix/);
});

test("filters selected severities", () => {
  const result = inventory([
    alert(1),
    alert(2, {security_advisory: {severity: "low", ghsa_id: "GHSA-low"}}),
  ], {excludedSeverities: ["HIGH", "low"]});

  assert.deepEqual(result.included, []);
  assert.deepEqual(result.excluded.map(value => value.exclusionReason), ["severity is high", "severity is low"]);
});

test("sorts alerts by severity then stable identifying fields", () => {
  const result = inventory([
    alert(4, {security_advisory: {severity: "low", ghsa_id: "GHSA-4"}}),
    alert(3, {security_advisory: {severity: "critical", ghsa_id: "GHSA-3"}}),
    alert(2, {security_advisory: {severity: "high", ghsa_id: "GHSA-2"}, dependency: {package: {name: "z", ecosystem: "npm"}, manifest_path: "b/package.json"}}),
    alert(1, {security_advisory: {severity: "high", ghsa_id: "GHSA-1"}, dependency: {package: {name: "a", ecosystem: "npm"}, manifest_path: "a/package.json"}}),
  ]);

  assert.deepEqual(result.included.map(value => value.number), [3, 1, 2, 4]);
});
