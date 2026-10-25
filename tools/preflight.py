#!/usr/bin/env python3
"""
HFL repository preflight. Catches the problems that keep recurring:

  1. machine-specific paths in code or docs (e.g. /Users/<name>/Desktop/...)
  2. template placeholders left in (<Title>, Project NN, TODO, <paste ...>)
  3. respondent-level data tracked in git (.dta/.sav/.zip, or .csv outside output/ and docs/)
  4. broken relative links in Markdown files
  5. required files missing
  6. CITATION.cff repository-code not matching this repository

Run from anywhere:   python3 tools/preflight.py
Runs automatically on every push via .github/workflows/preflight.yml.
Exit code 1 if any check fails. Logs are not scanned for paths: they are run
receipts and are never hand-edited.
"""
import logging
import os
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(levelname)-7s %(message)s")
log = logging.getLogger("preflight")

REPO = Path(__file__).resolve().parent.parent
os.chdir(REPO)

IS_TEMPLATE = (os.environ.get("GITHUB_REPOSITORY", "").endswith("/hfl-project-template")
               or REPO.name == "hfl-project-template")

files = subprocess.run(["git", "ls-files"], capture_output=True, text=True, check=True).stdout.split("\n")
files = [f for f in files if f]
dirs = set()
for f in files:
    d = os.path.dirname(f)
    while d:
        dirs.add(d)
        d = os.path.dirname(d)

TEXT_EXT = {".md", ".do", ".py", ".cff", ".txt", ".yml", ".yaml", ".sh", ".R"}
SKIP_PATH_SCAN = ("logs/", "tools/preflight.py")
failures = []


def fail(check, msg):
    failures.append((check, msg))
    log.error("[%s] %s", check, msg)


def text_files():
    for f in files:
        if Path(f).suffix in TEXT_EXT and Path(f).is_file():
            yield f, Path(f).read_text(encoding="utf-8", errors="ignore")


# 1. machine paths
MACHINE = re.compile(r"(/Users/[A-Za-z0-9._-]+|/home/[a-z][A-Za-z0-9._-]*/|[A-Za-z]:\\\\Users\\\\)")
for f, t in text_files():
    if f.startswith(SKIP_PATH_SCAN):
        continue
    for i, line in enumerate(t.splitlines(), 1):
        if MACHINE.search(line):
            fail("machine-path", f"{f}:{i}: {line.strip()[:120]}")

# 2. placeholders
PLACEHOLDER = re.compile(r"(<Title>|Project NN|PROJECT NN|<paste|<raw file>|<Source>|<provider>|<URL>|\bTODO\b|\bTBD\b|FIXME)")
for f, t in text_files():
    if f.startswith(("tools/", ".github/")):
        continue
    for i, line in enumerate(t.splitlines(), 1):
        if PLACEHOLDER.search(line):
            (log.warning if IS_TEMPLATE else lambda *a: fail("placeholder", a[1] % a[2:]))(
                "[placeholder] %s", f"{f}:{i}: {line.strip()[:120]}")

# 3. respondent data
ALLOWED_CSV_DIRS = ("output/", "docs/")
for f in files:
    low = f.lower()
    if low.endswith((".dta", ".sav", ".zip", ".parquet", ".xlsx")):
        fail("data", f"tracked data file: {f}")
    elif low.endswith(".csv") and not low.startswith(ALLOWED_CSV_DIRS):
        fail("data", f"tracked CSV outside output/ or docs/: {f}")

# 4. broken links
for f in files:
    if not f.endswith(".md"):
        continue
    t = Path(f).read_text(encoding="utf-8", errors="ignore")
    for m in re.finditer(r"\]\(([^)\s]+)\)", t):
        u = m.group(1)
        if u.startswith(("http", "mailto:", "#")):
            continue
        p = urllib.parse.unquote(u.split("#")[0])
        tgt = os.path.normpath(os.path.join(os.path.dirname(f), p))
        if tgt not in files and tgt not in dirs:
            (log.warning if IS_TEMPLATE else lambda *a: fail("link", a[1] % a[2:]))(
                "[link] %s", f"{f}: -> {u}")

# 5. required files
for req in ["README.md", "LICENSE", "CITATION.cff", ".gitignore", "data/README.md"]:
    if req not in files:
        fail("required", f"missing {req}")
if "requirements.txt" not in files and "code/requirements.txt" not in files:
    fail("required", "missing requirements.txt (root or code/)")

# 6. CITATION repository-code
repo_name = os.environ.get("GITHUB_REPOSITORY", "").split("/")[-1]
if not repo_name:
    url = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True, text=True).stdout.strip()
    repo_name = re.sub(r"\.git$", "", url.rstrip("/").split("/")[-1].split(":")[-1]) if url else ""
if repo_name and "CITATION.cff" in files and not IS_TEMPLATE:
    m = re.search(r"repository-code:\s*\"?([^\"\n]+)", Path("CITATION.cff").read_text())
    if m and not m.group(1).rstrip("/").endswith("/" + repo_name):
        fail("citation", f"CITATION.cff repository-code is {m.group(1)}, repo is {repo_name}")

log.info("checked %d tracked files%s", len(files), " (template mode: placeholders/links are warnings)" if IS_TEMPLATE else "")
if failures:
    log.error("%d problem(s) found", len(failures))
    sys.exit(1)
log.info("preflight passed")
