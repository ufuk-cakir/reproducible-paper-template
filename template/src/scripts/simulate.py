"""Cached result: the mean squared displacement of many random walkers.

This stands in for an expensive run (a training job, a big simulation). Its
output, src/data/random_walks.npz, is committed. The Snakefile defines the
rule that runs this script only under `./build.sh --regenerate`, so a normal
build and CI read the committed file and never rerun it.
"""

import numpy as np

import paths

rng = np.random.default_rng(1)
n_walkers, n_steps = 10_000, 500
positions = np.cumsum(rng.choice([-1, 1], size=(n_walkers, n_steps)), axis=1)

np.savez(
    paths.data / "random_walks.npz",
    t=np.arange(1, n_steps + 1),
    msd=np.mean(positions.astype(float) ** 2, axis=0),
    n_walkers=n_walkers,
)
