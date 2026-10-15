"""Rules for the files that showyourwork cannot work out from ms.tex alone.

showyourwork reads src/tex/ms.tex first. For a figure environment with
\\script{name.py} and \\includegraphics{figures/name.pdf}, it makes the rule
itself: run src/scripts/name.py, expect src/tex/figures/name.pdf. That rule
knows only the script, so write a rule here when a script

- reads a data file or a shared module (list it under `input`, so a change
  to it rebuilds the output),
- writes more than one file, or
- writes a number or table that ms.tex reads with \\variable or \\input.

The figures and numbers below are examples; replace them with your own.
"""

import os

# Template-owned fixes for showyourwork with Snakemake 9. Keep this line first.
include: "showyourwork-fixes.smk"

# Expensive results are committed to src/data/. Their rules exist only in
# `./build.sh --regenerate`, so a normal build (and CI) reads the committed
# file and can never start a long run or overwrite a result.
REGENERATE = os.environ.get("PAPER_REGENERATE") == "true"

if REGENERATE:

    rule random_walks:
        input:
            script="src/scripts/simulate.py",
        output:
            "src/data/random_walks.npz",
        shell:
            "python {input.script}"


rule spread_figure:
    input:
        script="src/scripts/spread.py",
        data="src/data/random_walks.npz",
    output:
        "src/tex/figures/spread.pdf",
    shell:
        "python {input.script}"


rule results:
    input:
        script="src/scripts/results.py",
        data="src/data/random_walks.npz",
    output:
        "src/tex/output/slope.txt",
        "src/tex/output/results_table.tex",
    shell:
        "python {input.script}"
