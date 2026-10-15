"""Figure 2: mean squared displacement against time, from the cached result.

This script reads src/data/random_walks.npz, so it needs a Snakefile rule that
lists that file as an input. Then a new result rebuilds the figure.
"""

import matplotlib.pyplot as plt
import numpy as np

import paths

result = np.load(paths.data / "random_walks.npz")

fig, ax = plt.subplots(figsize=(4, 2.5))
ax.plot(result["t"], result["msd"], lw=1.5, label="simulation")
ax.plot(result["t"], result["t"], "k--", lw=1, label="$t$")
ax.set_xlabel("step $t$")
ax.set_ylabel(r"$\langle x_t^2 \rangle$")
ax.legend(frameon=False)
fig.tight_layout()
fig.savefig(paths.figures / "spread.pdf")
