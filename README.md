# Reproducible paper template

A [Copier](https://copier.readthedocs.io) template for a LaTeX paper in which
figures and results are reproducible and rebuilt from code. When new code is
pushed to `main`, the GitHub Actions workflow rebuilds new figures and the PDF
and then publishes it to the `pdf` branch.

The template uses [showyourwork](https://show-your.work), pinned to a version
that works, with fixes for the problems we hit in a real paper. It also comes
with instructions for coding agents (`AGENTS.md`).

## Create a paper

```bash
uvx copier copy <template-url> my-paper
```

Copier asks for the paper title, your name, and the repository name. It
writes the paper into `my-paper/` and prints the next steps: make the folder
a git repository, build it, and push it to a new private GitHub repository.
`<template-url>` is wherever this template lives: a GitHub URL such as
`gh:OWNER/reproducible-paper-template`, or the absolute path of a local
copy. Copier records it, and `copier update` reads it back later.

`uvx` comes with [uv](https://docs.astral.sh/uv/). Without uv,
`pipx run copier copy ...` works too.

The new paper's README explains how to build it, how the build works, and how
to add figures. Its source is [`template/README.md.jinja`](template/README.md.jinja).

## Update a paper

Inside the paper repository, with all work committed:

```bash
uvx copier update
```

Copier merges the template changes since the paper's last update into the
paper and records the new version in its `.copier-answers.yml`. Updates
change the build tooling, the CI, the agent guides, and the template part of
`AGENTS.md`. They never touch the paper's own files: its README, `Snakefile`,
`ms.tex`, `bib.bib`, and the example scripts and data. The list is
`_exclude` in `copier.yml`.

## Develop the template

```
.
├── copier.yml                  questions, Jinja settings, update rules
├── template/                   what a new paper gets
├── .github/workflows/
│   └── test-template.yml       CI: generate a test paper and build it
├── LICENSE
└── README.md
```

Files in `template/` that end in `.jinja` are filled in with the answers and
lose the suffix. They use `[[ answer ]]`, not `{{ answer }}`, so LaTeX braces
and GitHub workflow expressions stay untouched. All other files are copied as
they are.

Test a change before you commit it:

```bash
uvx copier copy --vcs-ref HEAD --defaults --data author_name=Test . /tmp/test-paper
cd /tmp/test-paper
git init -b main && git add -A && git commit -m test
./build.sh
```

`--vcs-ref HEAD` uses the newest commit of the template, plus any
uncommitted changes; without it, Copier uses the newest tag.

Release a version: papers update to the newest tag, so commit, then tag.

```bash
git tag v0.2.0
```

Use semantic versions. A new major version tells paper owners to read the
changes before they update.

## License

The template is MIT-licensed; see `LICENSE`. The files that a paper gets
from the template carry SPDX headers, and the paper gets the license text in
`LICENSES/MIT.txt`.

## AI usage disclaimer

This template was built with generative AI. Claude Opus 5.5 Extra (Anthropic,
October 2026), running in Claude Code, wrote most of it under the direction
of Ufuk Çakır:

- the build script, `Snakefile`, showyourwork fix, and CI workflows, adapted
  from the setup of the JaxWildfire DMLR 2026 paper, which Fable 5 (August 2026) helped to build
- the example paper and its figure scripts
- this README, `AGENTS.md`, and the guides in `docs/agents/`

Every commit with AI-written changes names Claude as
co-author for full transparency. Use at your own risk.
