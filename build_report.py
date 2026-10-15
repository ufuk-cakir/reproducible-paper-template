"""Build report for build.sh. Owned by the template.

build.sh uses it twice:

    showyourwork build --verbose ... 2>&1 | python build_report.py LOG [--dry-run]
    python build_report.py --after LOG STATUS [--dry-run]

The first form saves the showyourwork log unchanged to LOG and prints one line
per finished step. On a terminal it also keeps a live status line: progress,
running steps, and the latest output. The second form runs after the build,
with its exit status. On failure it prints the lines of LOG that explain the
error; on success it lists the LaTeX warnings a reader would see in the PDF.
Standard library only.
"""

import os
import re
import shutil
import sys
import threading
import time

after = sys.argv[1] == "--after"
log_path = sys.argv[2] if after else sys.argv[1]
dry_run = "--dry-run" in sys.argv
root = os.getcwd() + "/"
tty = sys.stdout.isatty()
color = (tty or os.environ.get("GITHUB_ACTIONS") == "true") and not os.environ.get("NO_COLOR")
SPINNER = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

JOB_START = re.compile(r"^Job (\d+): (.*?)\.*$")
JOB_DONE = re.compile(r"^Finished jobid: (\d+) ")
JOB_ERROR = re.compile(r"^Error in rule \S+, jobid: (\d+)$")
STEPS = re.compile(r"^(\d+) of (\d+) steps")
# Snakemake bookkeeping. An error message is the block of other lines that
# comes just before Snakemake's first "Full Traceback".
BOUNDARY = re.compile(
    r"^(\[\w{3} \w{3} [ \d]\d [\d:]{8} \d{4}\]|Job \d+:|Reason:|Finished jobid|\d+ of \d+ steps"
    r"|Waiting for running jobs|Select jobs|Selected jobs|Resources (before|after)|Ready jobs"
    r"|Execute \d+ jobs|Building DAG|Need to rerun|Handle temp|Updating checkpoint|Checkpoint dependency)"
)
# Lines never worth showing as the latest output.
QUIET = re.compile(
    r"^(\s*$|=+$|-+\s|\s+\w[\w ]*: |\S*: (True|False) \d+$|/\S+ /|SNAKEMAKE|Zenodo cache"
    r"|unlocking|Touching|General args|spawned job|Using shell|Provided cores|Rules claiming"
    r"|Assuming|Submitting|Job stats|job +count|\w+ +\d+$|Complete log|Elapsed time"
    r"|Nothing to be done|Done!|Conda environments|localrule |rule |checkpoint |Removing temp"
    r"|shared_storage|remote_exec|\s+Config file|DAG of jobs will be updated)"
)


def paint(code, text):
    return f"\033[{code}m{text}\033[0m" if color else text


if after:
    lines = open(log_path, errors="replace").read().splitlines()
    if sys.argv[3] != "0":
        # Take the block before Snakemake's first traceback. Without one, take
        # the last lines that are not bookkeeping.
        block, excerpt, interesting = [], None, []
        for line in lines:
            if line.startswith(("Full Traceback", "Error in rule")):
                excerpt = excerpt or list(block)
                continue
            if BOUNDARY.match(line):
                block = []
            elif "no valid rule to generate it" not in line:
                block.append(line.replace(root, ""))
            if not BOUNDARY.match(line) and not QUIET.match(line):
                interesting.append(line.replace(root, ""))
        lines = excerpt or interesting[-15:]
        # A LaTeX error: keep TeX's own error lines and the source line they point at.
        tex = []
        for i, line in enumerate(lines):
            if line.startswith("! "):
                tex += lines[i : i + 3]
            elif re.match(r"error: [^:]+\.tex:\d+: ", line):
                tex.append(line)
        print()
        for line in [line for line in (tex or lines) if line.strip()][-30:]:
            print("    " + paint("31", line))
        print()
    elif not dry_run and os.path.exists(".showyourwork/compile/ms.log"):
        # Problems a reader would see in the PDF, from the LaTeX log of the last
        # compile. TeX wraps its log at 79 columns, so join each message first.
        text = re.sub(r"\n(?!\n)", "", open(".showyourwork/compile/ms.log", errors="replace").read())
        found = re.findall(r"(Reference|Citation) `([^']+)' on page \d+ undefined on input line (\d+)", text)
        problems = [f"{kind} {key} is undefined (input line {line})" for kind, key, line in dict.fromkeys(found)]
        twice = re.findall(r"Label `([^']+)' multiply defined", text)
        problems += [f"Label {key} is defined twice" for key in dict.fromkeys(twice)]
        if problems:
            print(f"  {paint('33', '!')} {len(problems)} LaTeX warning(s) in ms.pdf")
            for problem in problems[:10]:
                print(paint("33", f"      {problem}"))
    sys.exit(0)


def describe(message):
    """A short label for a step, or None for showyourwork's internal steps."""
    if m := re.match(r"Generating figure output: (.+)", message):
        return "figure  " + m[1].removeprefix("src/tex/")
    if m := re.match(r"Running user rule (\S+)", message):
        return "rule    " + m[1]
    if message == "Preprocess: Generating XML tree":
        return "latex   read ms.tex"
    if message == "Compiling the article PDF":
        return "latex   compile ms.pdf"
    return None


def seconds(value):
    return f"{value:.1f}s" if value < 60 else f"{int(value // 60)}m{int(value % 60):02d}s"


running = {}  # job id -> [label, message, start time]
progress = {"done": 0, "total": 0, "activity": "starting showyourwork", "latest": ""}
lock = threading.Lock()
drawn = False
finished = False


def draw():
    """Redraw the two status lines below the printed lines."""
    global drawn
    width = shutil.get_terminal_size().columns - 1
    now = time.time()
    done, total = progress["done"], progress["total"]
    filled = 20 * done // total if total else 0
    bar = "█" * filled + "░" * (20 - filled)
    names = [label.split(None, 1)[1] if label else message for label, message, _ in running.values()]
    doing = ", ".join(names) or progress["activity"]
    since = min((start for *_, start in running.values()), default=now)
    head = f"  {SPINNER[int(now * 10) % len(SPINNER)]} {bar} {done}/{total}  "
    tail = f"  {seconds(now - since)}" if running else ""
    doing = doing[: max(0, width - len(head) - len(tail))]
    latest = ("    " + progress["latest"])[:width]
    sys.stdout.write(
        "\r\033[J" + paint("36", head[:4]) + head[4:] + paint("1", doing) + paint("2", tail)
        + "\n" + paint("2", latest) + "\033[1A\r"
    )
    sys.stdout.flush()
    drawn = True


def emit(text):
    """Print a permanent line above the status lines."""
    global drawn
    with lock:
        if drawn:
            sys.stdout.write("\r\033[J")
            drawn = False
        print(text, flush=True)
        if tty and not finished:
            draw()


def tick():
    while not finished:
        with lock:
            if not finished:
                draw()
        time.sleep(0.1)


log = open(log_path, "w")
if tty:
    sys.stdout.write("\033[?25l")  # hide the cursor while the status line moves
    threading.Thread(target=tick, daemon=True).start()

dry_pending = None
try:
    for raw in sys.stdin:
        log.write(raw)
        line = raw.rstrip("\n")
        if m := JOB_START.match(line):
            label = describe(m[2])
            running[m[1]] = [label, m[2], time.time()]
            if dry_run and label and not m[2].startswith("Preprocess"):
                dry_pending = label
        elif line.startswith("Reason: ") and dry_pending:
            reason = line[len("Reason: "):].split(";")[0].replace(root, "")
            reason = reason[: max(20, shutil.get_terminal_size().columns - 45)]
            emit(f"  {paint('36', '○')} {dry_pending:<38} {paint('2', reason)}")
            dry_pending = None
        elif m := JOB_DONE.match(line):
            label, message, start = running.pop(m[1], [None, "", time.time()])
            if label:
                emit(f"  {paint('32', '✓')} {label:<38} {paint('2', seconds(time.time() - start))}")
        elif m := JOB_ERROR.match(line):
            label, message, start = running.pop(m[1], [None, "", time.time()])
            emit(f"  {paint('31', '✗')} {label or message:<38} {paint('31', 'failed')}")
        elif m := STEPS.match(line):
            progress["done"], progress["total"] = int(m[1]), int(m[2])
        elif line.startswith("Building DAG"):
            progress["activity"] = "planning the workflow"
        elif line.startswith("Checkpoint dependency"):
            progress["activity"] = "checking what changed"
        if not BOUNDARY.match(line) and not QUIET.match(line):
            progress["latest"] = line.strip().replace(root, "")
except KeyboardInterrupt:
    sys.exit(130)
finally:
    with lock:
        finished = True
        if drawn:
            sys.stdout.write("\r\033[J")
        if tty:
            sys.stdout.write("\033[?25h")
        sys.stdout.flush()
    log.close()
