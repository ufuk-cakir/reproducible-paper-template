"""A number and a table for the text, from the cached result.

ms.tex reads the number with \\variable{output/slope.txt} and the table with
\\input{output/results_table.tex}. Never type a result into ms.tex by hand.
"""

import numpy as np

import paths

result = np.load(paths.data / "random_walks.npz")
t, msd = result["t"], result["msd"]
slope = np.polyfit(t, msd, 1)[0]

(paths.output / "slope.txt").write_text(f"{slope:.3f}")

rows = "\n".join(
    rf"    {step} & {msd[step - 1]:.1f} \\" for step in (10, 100, 500)
)
(paths.output / "results_table.tex").write_text(
    rf"""\begin{{tabular}}{{rr}}
    \toprule
    Step $t$ & $\langle x_t^2 \rangle$ \\
    \midrule
{rows}
    \bottomrule
\end{{tabular}}
"""
)
