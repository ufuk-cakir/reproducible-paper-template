# Add or change a figure, number, or table

Every output in the paper has one script in `src/scripts/` and one place in
`src/tex/ms.tex` that uses it. The examples in this template show each case:

| Case | Example script | Rule |
| --- | --- | --- |
| Figure from a script that reads no files | `walkers.py` | inferred by showyourwork |
| Figure from a data file or shared module | `spread.py` | `spread_figure` in `Snakefile` |
| Number or table in the text | `results.py` | `results` in `Snakefile` |
| Hand-made figure (drawing, photo) | none | none: put it in `src/static/` |

## 1. Pick the case

- The script reads only itself, and writes one file: no rule needed.
- The script reads anything else (a file in `src/data/`, a shared style
  module, another script's output), or writes more than one file: write a
  rule in `Snakefile` and list every file it reads under `input`. Without the
  rule, a change to those files does not rebuild the figure.
- The output is a number or a table: always write a rule.
- The figure is drawn by hand: copy it to `src/static/<name>.pdf` and skip to
  step 3. Leave out `\script{}` but keep `\includegraphics{figures/<name>.pdf}`
  and the `\label`; the build copies the file into `figures/`. Prefer a
  script when the figure shows data.
- The computation takes more than about a minute: read
  `docs/agents/cached-results.md` first.

## 2. Write the script

Name the script after its output: `src/scripts/<name>.py` writes
`src/tex/figures/<name>.pdf`.

```python
"""Figure: <one line saying what it shows>."""

import matplotlib.pyplot as plt
import numpy as np

import paths

rng = np.random.default_rng(0)  # fixed seed: the same figure on every build
...
fig.savefig(paths.figures / "<name>.pdf")
```

- Use `paths` for every file path. Scripts run from the repository root.
- Write exactly the file names that `ms.tex` (or the rule's `output`) names.
- Keep it fast. A figure script reruns whenever its inputs change.
- No network access. Download data once, commit it to `src/data/`, and read it
  from there (or ask the user where large data should live).
- A number goes to `paths.output / "<name>.txt"` as the bare formatted text,
  for example `f"{value:.3f}"`. A table goes to `paths.output / "<name>.tex"`.

## 3. Use it in ms.tex

A figure:

```latex
\begin{figure}[t]
  \centering
  \includegraphics[width=\linewidth]{figures/<name>.pdf}
  \caption{...}
  \label{fig:<name>}
  \script{<name>.py}
\end{figure}
```

- `\label` is required. Without it the build stops with "A figure defines a
  script but has no label".
- `\script{}` takes a path relative to `src/scripts/`, for example
  `\script{experiments/plot_loss.py}`.
- One `\script{}` per figure. Several `\includegraphics` may share it if the
  script writes all of them.

A number: `\variable{output/<name>.txt}`. showyourwork tracks it on its own.

A table, or any other generated `.tex` file:

```latex
\IfFileExists{output/<name>.tex}{\input{output/<name>.tex}}{}
```

and add the file to `showyourwork.yml`:

```yaml
dependencies:
  src/tex/ms.tex:
    - src/tex/output/<name>.tex
```

The guard is needed because showyourwork compiles `ms.tex` once before any
script runs, and a missing `\input` file stops that pass. The
`dependencies` entry is needed because showyourwork does not see `\input` on
its own. The same entry is needed for a hand-written file that `ms.tex`
inputs, such as `src/tex/sections/intro.tex`.

## 4. Write the rule (if step 1 said so)

```python
rule <name>:
    input:
        script="src/scripts/<name>.py",
        data="src/data/<file>",
    output:
        "src/tex/figures/<name>.pdf",
    shell:
        "python {input.script}"
```

## 5. Build and check

```bash
./build.sh src/tex/figures/<name>.pdf   # only this figure
./build.sh                              # the whole paper
```

Then look at the figure: open `src/tex/figures/<name>.pdf` and the page of
`ms.pdf` that holds it. Check that the margin icon next to the caption links
to your script.

## 6. Commit

Commit the script, `ms.tex`, and the `Snakefile` and `showyourwork.yml`
changes. Do not commit anything in `src/tex/figures/` or `src/tex/output/`.

## Remove an example

Delete its script, its block in `ms.tex`, its rule in `Snakefile`, and its
line in `showyourwork.yml`. Delete `src/data/random_walks.npz` and the
`random_walks` rule when no example uses them.
