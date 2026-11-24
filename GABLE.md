# Gable's build of OpenGrep

This repository is Gable's fork of [OpenGrep](https://github.com/opengrep/opengrep).
It carries a small number of parser enhancements on top of upstream releases
and publishes builds of them for Gable's products.

**This is not an official OpenGrep release.** It is not made or endorsed by the
OpenGrep project. Use [upstream OpenGrep](https://github.com/opengrep/opengrep)
unless you specifically need one of the enhancements listed in
[GABLE-MODIFICATIONS.md](GABLE-MODIFICATIONS.md).

## How the fork is organized

- `main` mirrors upstream `main` and receives no Gable commits.
- `gable/vX.Y.Z` base branches carry Gable's enhancements on top of upstream
  release `vX.Y.Z`, one branch per upstream version. A base branch is not
  itself a release: each release is a tag on it, `vX.Y.Z-gable.N`, and a base
  branch holds many over time.
- `fix/<topic>` branches, where present, hold one change each.

Every enhancement this fork carries, and why, is listed in
[GABLE-MODIFICATIONS.md](GABLE-MODIFICATIONS.md). The goal is to carry as few
as possible: an enhancement is dropped once an upstream release includes it.

## Releases

Each release provides the `opengrep` executable for Linux x86_64, Linux ARM64
and macOS ARM64, the complete corresponding source, the generic-AST
definitions, the license texts, the list of modifications, a manifest of how
the release was built, and SHA-256 checksums of every file. The executable
reports its build, for example `opengrep --core version: 2.0.0+gable.1.<commit>`.

## License

OpenGrep is licensed under the GNU Lesser General Public License version 2.1
(see [LICENSE](LICENSE) and [COPYRIGHT](COPYRIGHT)). The changes made by
Gable.ai are distributed under the same license. The generic-AST interface
definitions carry their own linking exception, reproduced in
[gable/licenses/ast_generic_v1-license.txt](gable/licenses/ast_generic_v1-license.txt).

## Reporting problems

This repository does not take issues. Report problems that also occur with an
official OpenGrep build to [OpenGrep](https://github.com/opengrep/opengrep/issues).
