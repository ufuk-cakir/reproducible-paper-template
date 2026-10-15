# Results that are slow to compute

A training run, a large simulation, or a sweep should not rerun on every
build, and it cannot run in CI. Store its result in the repository instead,
and let the build replot it.

The example is `src/scripts/simulate.py`, which writes
`src/data/random_walks.npz`. `spread.py` and `results.py` read that file.

## How it works

- The result file is committed to `src/data/`.
- The rule that writes it sits inside `if REGENERATE:` in the `Snakefile`.
  A normal `./build.sh` (and CI) does not define that rule, so it reads the
  committed file and can never start the long run or overwrite the result.
- `./build.sh --regenerate` defines the rule. Snakemake then reruns it only
  if its script or its inputs changed, and rebuilds everything that reads it.
- Every rule that reads the result lists it under `input`, so a new result
  rebuilds its figures, numbers, and tables.

## Add one

1. Write `src/scripts/<name>.py`. It writes the result to
   `paths.data / "<name>.<ext>"`. Prefer small, plain formats: `.npz`,
   `.csv`, `.json`. Save the summary the figures need, not raw checkpoints.
2. Add its rule inside the `if REGENERATE:` block:

   ```python
   if REGENERATE:

       rule <name>:
           input:
               script="src/scripts/<name>.py",
           output:
               "src/data/<name>.<ext>",
           shell:
               "python {input.script}"
   ```

3. List `src/data/<name>.<ext>` under `input` of each rule that reads it.
4. Ask the user before running it. Then run `./build.sh --regenerate`.
5. Commit the script, the rule, and the result file together, so the
   result always matches the code that made it.

## A result computed somewhere else

For a job that runs on a cluster or a GPU machine, keep the script in the
repository anyway, run it there, and copy the output into `src/data/`.
Commit it with a message that names the machine and the commit it ran from.
The `if REGENERATE:` rule still documents how to recompute it.

## Size

Git is fine for files up to a few MB. For larger results, ask the user.
showyourwork can deposit large files on Zenodo; see
<https://show-your.work/en/latest/zenodo/>.

## When the build says a result is missing

```
Missing input files for rule <rule>:
    affected files:
        src/data/<name>.<ext>
```

The committed result is missing. Restore it from git, or ask the user
whether to run `./build.sh --regenerate`.
