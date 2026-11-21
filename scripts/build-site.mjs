#!/usr/bin/env node
/**
 * Build the PIKA SH static site.
 *
 * One build, two hosts:
 *   - GitHub Pages  (.github/workflows/pages-deploy.yml)
 *   - EdgeOne Pages (edgeone.json -> buildCommand)
 *
 * Output layout (_site/):
 *   /                    VitePress site (home page + guide)
 *   /Menu.sh             entry script
 *   /Linux/**, /WinNT/** mirror copies so the CDN paths keep working
 *   /.pika-healthz       mirror probe used by the scripts
 *   /pika-healthz.txt    same probe for hosts that strip dotfiles
 */

import { spawnSync } from "node:child_process";
import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const docsDir = join(root, "docs");
const distDir = join(docsDir, ".vitepress", "dist");
const outDir = join(root, "_site");

// EdgeOne Pages rejects single files above 25 MB; stay a little below that.
const MAX_FILE_BYTES = 24 * 1024 * 1024;

const log = (msg) => console.log(`[site] ${msg}`);

function runBuild() {
  // Prefer the local CLI so the build needs no shell and no npm wrapper.
  const bin = join(docsDir, "node_modules", "vitepress", "bin", "vitepress.js");
  if (existsSync(bin)) {
    const result = spawnSync(process.execPath, [bin, "build"], { cwd: docsDir, stdio: "inherit" });
    if (result.error) throw result.error;
    if (result.status !== 0) process.exit(result.status ?? 1);
    return;
  }

  // Fallback: npm script (handles hoisted installs).
  const npm = process.platform === "win32" ? "npm.cmd" : "npm";
  const result = spawnSync(npm, ["run", "docs:build"], { cwd: docsDir, stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}

function copyFileIfExists(from, to) {
  if (!existsSync(from)) return false;
  mkdirSync(dirname(to), { recursive: true });
  copyFileSync(from, to);
  return true;
}

// Copy a tree, skipping oversized files instead of failing the whole deploy.
function copyTree(from, to) {
  let skipped = 0;
  cpSync(from, to, {
    recursive: true,
    dereference: false,
    filter: (src) => {
      if (basename(src) === "node_modules") return false;
      const st = statSync(src);
      if (st.isFile() && st.size > MAX_FILE_BYTES) {
        skipped += 1;
        console.warn(`[site] skip oversized file (${(st.size / 1048576).toFixed(1)} MB): ${src.slice(root.length + 1)}`);
        return false;
      }
      return true;
    },
  });
  if (skipped > 0) console.warn(`[site] ${skipped} file(s) skipped from ${from.slice(root.length + 1)}`);
}

function main() {
  if (!existsSync(join(docsDir, "package.json"))) {
    console.error("[site] docs/package.json not found — run from the repository root.");
    process.exit(1);
  }

  log("building VitePress site");
  runBuild();

  if (!existsSync(join(distDir, "index.html"))) {
    console.error(`[site] build output missing: ${distDir}/index.html`);
    process.exit(1);
  }

  log("assembling _site");
  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });

  // 1) VitePress output at the site root
  cpSync(distDir, outDir, { recursive: true });

  // 2) Mirror tree: the scripts are served from the same domain they probe
  for (const dir of ["Linux", "WinNT"]) {
    const src = join(root, dir);
    if (existsSync(src)) copyTree(src, join(outDir, dir));
  }
  for (const file of [
    "Menu.sh",
    "README.MD",
    "CONTRIBUTING.md",
    "THIRD_PARTY_NOTICES.md",
    "LICENSE",
    "LICENSE-MIT",
    "CNAME",
  ]) {
    copyFileIfExists(join(root, file), join(outDir, file));
  }

  // 3) Mirror probe: dotfile for existing scripts, plain txt for hosts that
  //    refuse to serve dotfiles.
  const healthz = join(root, ".pika-healthz");
  if (existsSync(healthz)) {
    copyFileSync(healthz, join(outDir, ".pika-healthz"));
    copyFileSync(healthz, join(outDir, "pika-healthz.txt"));
  } else {
    const body = "PIKA_SH_OK\nversion=1.0\n";
    writeFileSync(join(outDir, ".pika-healthz"), body);
    writeFileSync(join(outDir, "pika-healthz.txt"), body);
  }

  const files = countFiles(outDir);
  log(`done: ${outDir} (${files} files)`);
}

function countFiles(dir) {
  let n = 0;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    n += entry.isDirectory() ? countFiles(join(dir, entry.name)) : 1;
  }
  return n;
}

main();
