"""Figure 1: a few random-walk trajectories.

The simplest case. ms.tex names this script with \\script{walkers.py} inside
the figure, so showyourwork makes the rule by itself: no Snakefile entry.
"""

import matplotlib.pyplot as plt
import numpy as np

import paths

rng = np.random.default_rng(0)
steps = rng.choice([-1, 1], size=(5, 200))
positions = np.cumsum(steps, axis=1)

fig, ax = plt.subplots(figsize=(4, 2.5))
ax.plot(positions.T, lw=1)
ax.set_xlabel("step $t$")
ax.set_ylabel("position $x_t$")
fig.tight_layout()
fig.savefig(paths.figures / "walkers.pdf")
