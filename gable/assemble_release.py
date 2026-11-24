#!/usr/bin/env python3
"""Collect a Gable release's files, its manifest and its checksums in one directory.

The release workflow runs this after the builds and the source archive finish.
`--artifacts` holds what those jobs uploaded:

    opengrep_<platform>/opengrep_<platform>.tgz      the executable
    opengrep_<platform>/build-info-<platform>.json   how it was built
    opengrep_linux_x86/ast_generic_v1_t.ml           the generated AST types
    source/opengrep-<tag>-source.tar.gz              the complete source
    source/GABLE-MODIFICATIONS.md                    its list of modifications

The modifications list comes from the stamped source, so it includes the
version stamp; everything else comes from the checked-out release commit. The
output holds the release assets, a manifest.json describing them and how they
were built, and SHA256SUMS covering every other file. Files added afterwards,
such as signatures, need SHA256SUMS written again.
"""

import argparse
import hashlib
import json
import shutil
import subprocess
import tarfile
from pathlib import Path

PLATFORMS = ("linux_x86", "linux_aarch64", "osx_arm64")
REPOSITORY_FILES = {
    "interfaces/semgrep_interfaces/ast_generic_v1.atd": "ast_generic_v1.atd",
    "LICENSE": "LICENSE",
    "COPYRIGHT": "COPYRIGHT",
    "gable/licenses/ast_generic_v1-license.txt": "ast_generic_v1-license.txt",
}


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as content:
        for block in iter(lambda: content.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()


def extract_executable(archive, platform, out):
    """Unpack the one executable in `archive` as opengrep_<platform>, keeping its mode."""
    with tarfile.open(archive) as tgz:
        members = [m for m in tgz.getmembers() if m.isreg()]
        if len(members) != 1:
            raise SystemExit(f"{archive} should hold exactly one file, holds {len(members)}")
        target = out / f"opengrep_{platform}"
        with tgz.extractfile(members[0]) as source, open(target, "wb") as dest:
            shutil.copyfileobj(source, dest)
        target.chmod(0o755)
    return target.name


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--tag", required=True)
    parser.add_argument("--artifacts", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--run-url", default="", help="the workflow run that built the release")
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    builds = {}
    for platform in PLATFORMS:
        folder = args.artifacts / f"opengrep_{platform}"
        name = extract_executable(folder / f"opengrep_{platform}.tgz", platform, args.out)
        builds[platform] = {"file": name, **json.loads((folder / f"build-info-{platform}.json").read_text())}

    source = args.artifacts / "source" / f"opengrep-{args.tag}-source.tar.gz"
    shutil.copy2(source, args.out / source.name)
    shutil.copyfile(args.artifacts / "source" / "GABLE-MODIFICATIONS.md", args.out / "GABLE-MODIFICATIONS.md")
    # copyfile, not copy2: dune leaves generated files read-only.
    shutil.copyfile(args.artifacts / "opengrep_linux_x86" / "ast_generic_v1_t.ml", args.out / "ast_generic_v1_t.ml")
    for path, name in REPOSITORY_FILES.items():
        shutil.copy2(path, args.out / name)

    versions = {build["version"] for build in builds.values()}
    if len(versions) != 1:
        raise SystemExit(f"the executables report different versions: {sorted(versions)}")

    files = sorted(p.name for p in args.out.iterdir() if p.name not in ("SHA256SUMS", "manifest.json"))
    manifest = {
        "tag": args.tag,
        "version": versions.pop(),
        "commit": git("rev-parse", "HEAD"),
        "upstream_base": args.tag.split("-gable.")[0],
        "run": args.run_url,
        "builds": builds,
        "source_archive": source.name,
        "files": {name: sha256(args.out / name) for name in files},
    }
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

    sums = sorted(p.name for p in args.out.iterdir() if p.name != "SHA256SUMS")
    (args.out / "SHA256SUMS").write_text("".join(f"{sha256(args.out / n)}  {n}\n" for n in sums))


if __name__ == "__main__":
    main()
