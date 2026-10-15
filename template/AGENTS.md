# Agent guide

This repository is a paper built with
[showyourwork](https://show-your.work). Every figure, number, and table in
the PDF is the output of a script in `src/scripts/`. `./build.sh` reruns the
scripts whose inputs changed and compiles `ms.pdf`.

## Rules

- Build with `./build.sh`. Never run latexmk, pdflatex, or tectonic directly,
  and never run a figure script by hand to "update" a figure.
- Never commit generated files: `src/tex/figures/`, `src/tex/output/`, and
  `ms.pdf`. Their `.gitignore` files exclude them. Do not force-add them.
- Never type a result into `ms.tex`. A script writes it to `src/tex/output/`,
  and `ms.tex` reads it with `\variable{}` or `\input{}`.
- Never run `./build.sh --regenerate` unless the user asks. It recomputes and
  overwrites the committed results in `src/data/`.
- Do not edit template-owned files: `build.sh`, `build_report.py`,
  `showyourwork-fixes.smk`, `environment.yml`, `.github/workflows/`, and
  `docs/agents/`. Template updates (`uvx copier update`, run only when the
  user asks) replace them. Never edit `.copier-answers.yml`. Put
  paper-specific instructions under "This paper" below.
- Add Python packages with `uv add <package>`, which updates `pyproject.toml`
  and `uv.lock`. Do not use pip.
- Software that a result depends on must be cited. When you add a package,
  tell the user and point to the citation its project asks for (its
  `CITATION.cff`, `CITATION.bib`, or docs). Edit `src/tex/bib.bib` and the
  Software section of `ms.tex` only if the user agrees, and never write a
  BibTeX entry from memory.
- After a change, build and look at the result: read the page of `ms.pdf`
  that holds the figure, not only the build exit code.

## Tasks

| Task | Read |
| --- | --- |
| Add or change a figure, number, or table | `docs/agents/new-figure.md` |
| Add a result that is slow to compute | `docs/agents/cached-results.md` |
| Build fails, or the PDF does not show a change | `docs/agents/build.md` |

## Layout

```
ms.tex lives in src/tex/; the build writes ./ms.pdf
src/scripts/         one script per figure, number, or table; paths.py
src/data/            committed inputs and cached results
src/static/          hand-made figures, copied into the build as-is
src/tex/figures/     generated figures (git-ignored)
src/tex/output/      generated numbers and tables (git-ignored)
Snakefile            rules for scripts that showyourwork cannot infer
showyourwork.yml     \input dependencies of ms.tex, PDF stamp
```

showyourwork requires the folder names under `src/`; they cannot be renamed.

## This paper

<!-- Paper-specific instructions go below this line. -->
