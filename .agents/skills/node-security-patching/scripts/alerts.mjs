#!/usr/bin/env node
import {parseJson, repository, run, ToolError} from "./lib.mjs";

const severityOrder = {critical: 0, high: 1, medium: 2, low: 3};

export function normalizeAlert(alert) {
  const dependency = alert.dependency ?? {};
  const advisory = alert.security_advisory ?? {};
  const vulnerability = alert.security_vulnerability ?? {};
  return {
    number: alert.number,
    package: dependency.package?.name,
    ecosystem: dependency.package?.ecosystem,
    manifestPath: dependency.manifest_path,
    relationship: dependency.relationship ?? null,
    scope: dependency.scope ?? null,
    severity: advisory.severity?.toLowerCase(),
    cve: advisory.cve_id ?? null,
    ghsa: advisory.ghsa_id ?? null,
    vulnerableRange: vulnerability.vulnerable_version_range ?? null,
    patchedVersion: vulnerability.first_patched_version?.identifier ?? null,
    url: alert.html_url ?? null,
  };
}

export function inventory(alerts, {excludedProjects = [], excludedSeverities = []} = {}) {
  const included = [];
  const excluded = [];
  const projects = excludedProjects.map(pattern => pattern.toLowerCase());
  const severities = excludedSeverities.map(severity => severity.toLowerCase());
  for (const alert of alerts.map(normalizeAlert)) {
    if (alert.ecosystem !== "npm") continue;
    const project = projects.find(pattern => (alert.manifestPath ?? "").toLowerCase().includes(pattern));
    if (project) {
      excluded.push({...alert, exclusionReason: `manifest path matches ${project}`});
    } else if (severities.includes(alert.severity)) {
      excluded.push({...alert, exclusionReason: `severity is ${alert.severity}`});
    } else {
      included.push(alert);
    }
  }
  const sort = (a, b) => (severityOrder[a.severity] ?? 4) - (severityOrder[b.severity] ?? 4)
    || (a.manifestPath ?? "").localeCompare(b.manifestPath ?? "")
    || (a.package ?? "").localeCompare(b.package ?? "")
    || a.number - b.number;
  return {included: included.sort(sort), excluded: excluded.sort(sort)};
}

function exclusionsFromArgs(args) {
  const exclusions = {excludedProjects: [], excludedSeverities: []};
  for (let index = 0; index < args.length; index += 1) {
    const option = args[index];
    const value = args[index + 1];
    if (option === "--exclude-project" && value) exclusions.excludedProjects.push(value);
    else if (option === "--exclude-severity" && value) exclusions.excludedSeverities.push(value);
    else throw new ToolError(`Unknown or incomplete option: ${option}`, 2);
    index += 1;
  }
  return exclusions;
}

async function main() {
  const repo = await repository();
  const {stdout} = await run("gh", ["api", "--paginate", "--slurp", `repos/${repo}/dependabot/alerts?state=open&per_page=100`]);
  const pages = parseJson(stdout, "Dependabot alerts");
  if (!Array.isArray(pages) || !pages.every(Array.isArray)) throw new ToolError("Dependabot alerts response is not a paginated array", 2);
  const exclusions = exclusionsFromArgs(process.argv.slice(2));
  console.log(JSON.stringify({repository: repo, exclusions, ...inventory(pages.flat(), exclusions)}, null, 2));
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  main().catch(error => {
    console.error(error.message);
    process.exit(error.exitCode ?? 3);
  });
}
