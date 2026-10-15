# Building and debugging

## Commands

```bash
./build.sh                             # build ms.pdf
./build.sh src/tex/figures/<name>.pdf  # build one file
./build.sh --dry-run --verbose         # list the jobs that would run, and why
./build.sh --regenerate                # recompute cached results (ask first)
```

`build.sh` installs the pinned uv and Tectonic into `.cache/` if needed,
syncs `.venv/` from `uv.lock`, and runs `showyourwork build`. The full log of
the last run is `.showyourwork/build.log`. The first build downloads the TeX
packages, so it takes a few minutes; later builds take seconds.

## What a build does

1. **Preprocess.** showyourwork compiles `ms.tex` once and records each
   figure environment's `\script`, `\includegraphics`, and `\label`, every
   `\variable`, and the dependencies in `showyourwork.yml`.
2. **Plan.** It turns those into Snakemake jobs: one inferred job per figure
   with a `\script`, plus the rules in `Snakefile`.
3. **Run.** Snakemake runs only the jobs whose outputs are missing or whose
   input contents changed.
4. **Compile.** Tectonic compiles `ms.pdf` with links from each figure to its
   script at the current commit, and a stamp with the commit hash.

Every build recompiles the LaTeX (a few seconds), even with no changes. This
comes from a fix in `showyourwork-fixes.smk`. Figure scripts rerun only when
needed.

## Errors

| Message | Cause | Fix |
| --- | --- | --- |
| A Python traceback, then `Error in rule ...` | The script failed | Fix the script; rerun its target |
| ``LaTeX Error: File `output/<x>.tex' not found`` | Unguarded `\input` of a generated file | Use `\IfFileExists{...}{\input{...}}{}` (see `new-figure.md`) |
| `Missing input files for rule ...` naming `src/data/...` | A cached result is missing | Restore it from git, or ask about `--regenerate` |
| `A figure defines a script but has no label` | A figure environment has `\script` but no `\label` | Add a `\label` |
| `MissingOutputException` | The script wrote a different file name than the rule or `\includegraphics` expects | Make the names match |
| `MissingInputException` for `src/tex/figures/<x>.pdf` | No rule makes the file: no `\script` and no Snakefile rule | Add one |
| `File ... is present on disk, but there is no valid rule to generate it` | Informational; a later error is the real one | Read further down |

## The PDF does not show a change

- An edited `\input` file: is it listed under `dependencies` in
  `showyourwork.yml`?
- An edited module that a script imports: is it an `input` of a Snakefile
  rule for that figure? An inferred rule knows only the script itself.
- Snakemake skips an input whose timestamp changed but whose content did not,
  so `touch` may not trigger a rebuild. A real edit does.
- To force one output, delete it and build: `rm src/tex/figures/<name>.pdf`,
  then `./build.sh`. (`--forcerun` does not work through showyourwork.)

## CI

`.github/workflows/build.yml` runs `./build.sh` on every push to `main` and
force-pushes `ms.pdf` and `arxiv.tar.gz` to the `pdf` branch. Pull requests
build too and publish to `pdf-pr-<N>`. When CI fails, download the
`build-logs-*` artifact from the run. A push to `pdf` that fails with 403
needs Settings > Actions > General > Workflow permissions set to "Read and
write".
