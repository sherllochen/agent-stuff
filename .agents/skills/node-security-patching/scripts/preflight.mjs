#!/usr/bin/env node
import {execFileSync} from "node:child_process";

function fail(message) {
  console.error(message);
  process.exit(2);
}

try {
  const version = execFileSync("corepack", ["yarn", "--version"], {encoding: "utf8"}).trim();
  if (!version.startsWith("4.")) fail(`Yarn 4 is required; Corepack selected Yarn ${version || "unknown"}.`);
} catch (error) {
  if (error.status === 2) process.exit(2);
  fail("Corepack with Yarn 4 is required. Install a supported Node.js release and run: corepack enable");
}
