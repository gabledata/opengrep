#!/usr/bin/env python3
"""Pack the complete corresponding source of a release into one archive.

GitHub's automatic source archives leave out submodules, so this packs every
file Git tracks, submodules included, under a single top-level directory. The
`tests/semgrep-rules` submodule is test content under different terms (LGPL
plus Commons Clause) and is not needed to build the parser, so it is left out.

The archive is reproducible: entries are sorted, owned by root, and dated with
the commit time, so the same commit always produces the same bytes.

    gable/source_archive.py --output opengrep-v2.0.0-gable.1-source.tar.gz \\
        --prefix opengrep-v2.0.0-gable.1 --extra build/opam.locked=opam.locked
"""

import argparse
import gzip
import io
import os
import stat
import subprocess
import tarfile
from pathlib import Path

EXCLUDED = ("tests/semgrep-rules/",)


def tracked_files():
    listing = subprocess.run(
        ["git", "ls-files", "--recurse-submodules", "-z"], check=True, capture_output=True
    ).stdout
    paths = (p.decode() for p in listing.split(b"\0") if p)
    return sorted(p for p in paths if not p.startswith(EXCLUDED))


def check_submodules():
    """Stop unless every submodule is checked out at the commit the repository records.

    An uninitialized submodule still lists its empty directory, so the archive
    would quietly leave out its source.
    """
    status = subprocess.run(
        ["git", "submodule", "status", "--recursive"], check=True, capture_output=True, text=True
    ).stdout
    bad = [line[1:].split()[1] for line in status.splitlines() if line[:1] in ("-", "+", "U")]
    if bad:
        raise SystemExit("submodules not checked out at their recorded commits: " + ", ".join(bad)
                         + "; run git submodule update --init --recursive")


def commit_time():
    out = subprocess.run(["git", "log", "-1", "--format=%ct"], check=True, capture_output=True, text=True)
    return int(out.stdout.strip())


def add(archive, source, name, mtime):
    info = archive.gettarinfo(source, arcname=name)
    info.uid = info.gid = 0
    info.uname = info.gname = ""
    info.mtime = mtime
    if info.isreg():
        info.mode = 0o755 if os.stat(source).st_mode & stat.S_IXUSR else 0o644
        with open(source, "rb") as content:
            archive.addfile(info, content)
    else:
        archive.addfile(info)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--prefix", required=True, help="the archive's top-level directory")
    parser.add_argument("--extra", action="append", default=[], metavar="SOURCE=NAME",
                        help="also add the file SOURCE at NAME inside the prefix")
    args = parser.parse_args()

    check_submodules()
    mtime = commit_time()
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w", format=tarfile.PAX_FORMAT) as archive:
        for path in tracked_files():
            if not os.path.lexists(path):
                raise SystemExit(f"{path} is tracked but missing from the checkout")
            add(archive, path, f"{args.prefix}/{path}", mtime)
        for extra in args.extra:
            source, name = extra.split("=", 1)
            add(archive, source, f"{args.prefix}/{name}", mtime)
    with open(args.output, "wb") as out, gzip.GzipFile(filename="", mode="wb", fileobj=out, mtime=mtime) as gz:
        gz.write(buffer.getvalue())


if __name__ == "__main__":
    main()
