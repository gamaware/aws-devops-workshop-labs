"""Structure and documentation checks that keep the labs consistent (make docs-check).

- Every lab has README.md, starter/, solution/ and an executable tests/run.sh.
- Every lab README has the sections a learner relies on, in order.
- Every lab has instructor notes, and the repository README links every lab.
- Relative links in Markdown files point at files that exist.
- No placeholder markers (TODO, FIXME, TBD) in the documentation.
"""

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAB_SECTIONS = ["Objectives", "Prerequisites", "Duration", "Scenario", "Steps", "Expected result", "Reset"]
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
PLACEHOLDER = re.compile(r"\b(TODO|FIXME|TBD)\b")
SKIP_DIRS = {".git", ".venv", ".cache", "node_modules", ".terraform", "cdk.out", "styles"}


def markdown_files() -> list[Path]:
    files = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [name for name in dirnames if name not in SKIP_DIRS]
        files += [Path(dirpath, name) for name in filenames if name.endswith(".md")]
    return sorted(files)


def check_labs(errors: list[str]) -> list[Path]:
    labs = sorted(path for path in (ROOT / "labs").iterdir() if re.match(r"\d\d-", path.name))
    if not labs:
        errors.append("no labs found under labs/")
    for lab in labs:
        for required in ("README.md", "starter", "solution", "tests/run.sh"):
            if not (lab / required).exists():
                errors.append(f"{lab.name}: missing {required}")
        runner = lab / "tests" / "run.sh"
        if runner.exists() and not os.access(runner, os.X_OK):
            errors.append(f"{lab.name}: tests/run.sh is not executable")
        readme = lab / "README.md"
        if readme.exists():
            headings = re.findall(r"^## (.+)$", readme.read_text(), flags=re.MULTILINE)
            present = [heading for heading in headings if heading in LAB_SECTIONS]
            if present != LAB_SECTIONS:
                missing = [section for section in LAB_SECTIONS if section not in headings]
                errors.append(f"{lab.name}/README.md: sections missing or out of order: {missing or present}")
        if not list((ROOT / "instructor").glob(f"{lab.name}.md")):
            errors.append(f"{lab.name}: no instructor/{lab.name}.md")
    return labs


def check_readme_links_labs(labs: list[Path], errors: list[str]) -> None:
    readme = (ROOT / "README.md").read_text()
    for lab in labs:
        if f"labs/{lab.name}" not in readme:
            errors.append(f"README.md does not link labs/{lab.name}")


def check_markdown(errors: list[str]) -> None:
    for path in markdown_files():
        text = path.read_text()
        relative = path.relative_to(ROOT)
        for number, line in enumerate(text.splitlines(), start=1):
            if PLACEHOLDER.search(line):
                errors.append(f"{relative}:{number}: placeholder marker")
        for target in LINK.findall(text):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            file_part = target.split("#", 1)[0]
            if file_part and not (path.parent / file_part).exists():
                errors.append(f"{relative}: broken link {target}")


def main() -> int:
    errors: list[str] = []
    labs = check_labs(errors)
    check_readme_links_labs(labs, errors)
    check_markdown(errors)
    for error in errors:
        print(f"docs-check: {error}")
    if errors:
        return 1
    print(f"docs-check: {len(labs)} labs and {len(markdown_files())} Markdown files are consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
