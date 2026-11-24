#!/usr/bin/env python3
"""Stamp the Gable release into the version the executable reports.

    gable/set_version.py --tag v2.0.0-gable.1

rewrites src/core/Version.ml so `opengrep --core -version` reports
`2.0.0+gable.1.<commit>`. The part after `+` is semver build metadata, so the
version still compares equal to the upstream release it is based on. The tag's
base must match the upstream version the branch is on.
"""

import argparse
import re
import subprocess
from pathlib import Path

VERSION_ML = Path("src/core/Version.ml")
DEFINITION = re.compile(r'^let version = "([^"+]+)(?:\+[^"]*)?"$', re.M)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--tag", required=True, help="the release tag, vX.Y.Z-gable.N")
    args = parser.parse_args()

    tag = re.fullmatch(r"v(\d+\.\d+\.\d+)-gable\.(\d+)", args.tag)
    if tag is None:
        raise SystemExit(f"{args.tag} is not a Gable release tag of the form vX.Y.Z-gable.N")
    base, build = tag.groups()

    source = VERSION_ML.read_text()
    current = DEFINITION.search(source)
    if current is None:
        raise SystemExit(f"no version definition found in {VERSION_ML}")
    if current.group(1) != base:
        raise SystemExit(f"tag {args.tag} names upstream {base}, but this branch is on {current.group(1)}")

    commit = subprocess.run(["git", "rev-parse", "--short=12", "HEAD"], check=True,
                            capture_output=True, text=True).stdout.strip()
    version = f"{base}+gable.{build}.{commit}"
    VERSION_ML.write_text(DEFINITION.sub(f'let version = "{version}"', source, count=1))
    print(version)


if __name__ == "__main__":
    main()
