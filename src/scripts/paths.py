"""Absolute paths to the repository folders, for use in figure scripts.

    import paths
    fig.savefig(paths.figures / "my_figure.pdf")

Scripts run from the repository root, and src/scripts/ is on the import path
because Python puts the script's own folder there.
"""

from pathlib import Path

root = Path(__file__).resolve().parents[2]
src = root / "src"
data = src / "data"  # committed inputs and cached results
static = src / "static"  # hand-made figures, copied into the build
scripts = src / "scripts"  # one script per figure, number, or table
tex = src / "tex"  # the manuscript
figures = tex / "figures"  # generated figures, git-ignored
output = tex / "output"  # generated numbers and tables, git-ignored
