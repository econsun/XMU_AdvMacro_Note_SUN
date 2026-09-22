#!/usr/bin/env python3
"""Build and publish the tracked release PDF to GitHub."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
BUILD_PDF = PROJECT_ROOT / "_build" / "book" / "AdvMacroNote_Sun.pdf"
LEGACY_PDF = PROJECT_ROOT / "AdvMacroNote_Sun.pdf"
VERSION_PATTERN = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+$")


class ReleaseError(RuntimeError):
    pass


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print(f"+ {' '.join(command)}", flush=True)
    return subprocess.run(
        command, cwd=PROJECT_ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )


def output(command: list[str]) -> str:
    return run(command, capture=True).stdout.strip()


def require_clean_worktree() -> None:
    if output(["git", "status", "--porcelain"]):
        raise ReleaseError("发布前工作区必须干净，请先提交或暂存当前修改")


def validate(version: str) -> None:
    if not VERSION_PATTERN.fullmatch(version):
        raise ReleaseError("用法：make release VERSION=v2.1.0")
    if output(["git", "branch", "--show-current"]) != "main":
        raise ReleaseError("只能从 main 分支发布")
    if shutil.which("gh") is None:
        raise ReleaseError("找不到 gh，请先安装 GitHub CLI")
    require_clean_worktree()
    run(["gh", "auth", "status"])
    run(["git", "fetch", "origin", "main", "--tags"])
    if output(["git", "rev-parse", "HEAD"]) != output(["git", "rev-parse", "origin/main"]):
        raise ReleaseError("本地 main 必须与 origin/main 完全同步")
    tag_check = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", f"refs/tags/{version}"],
        cwd=PROJECT_ROOT,
    )
    if tag_check.returncode == 0:
        raise ReleaseError(f"标签已存在：{version}")


def release(version: str) -> None:
    validate(version)
    run([sys.executable, "_tools/build.py", "all"])
    require_clean_worktree()
    if not BUILD_PDF.is_file() or BUILD_PDF.stat().st_size == 0:
        raise ReleaseError("完整笔记构建失败或 PDF 为空")
    release_pdf = PROJECT_ROOT / f"AdvMacroNote_Sun_{version}.pdf"
    previous_pdfs = sorted(PROJECT_ROOT.glob("AdvMacroNote_Sun_v*.pdf"))
    tracked_pdfs = [LEGACY_PDF, *previous_pdfs, release_pdf]
    for old_pdf in [LEGACY_PDF, *previous_pdfs]:
        if old_pdf != release_pdf:
            old_pdf.unlink(missing_ok=True)
    shutil.copy2(BUILD_PDF, release_pdf)
    run(["git", "add", "-A", "--", *(path.name for path in tracked_pdfs)])
    run(["git", "commit", "-m", f"release: publish {version}"])
    run(["git", "tag", "-a", version, "-m", f"Release {version}"])
    run(["git", "push", "--atomic", "origin", "main", f"refs/tags/{version}"])
    with tempfile.TemporaryDirectory(prefix="advanced-macro-release-") as temporary:
        latest_pdf = Path(temporary) / "AdvMacroNote_Sun_latest.pdf"
        shutil.copy2(release_pdf, latest_pdf)
        run([
            "gh", "release", "create", version, release_pdf.name, str(latest_pdf),
            "--title", version, "--generate-notes", "--latest",
        ])
    print(f"发布完成：{version}")


def main() -> int:
    try:
        release(sys.argv[1] if len(sys.argv) == 2 else "")
    except (ReleaseError, subprocess.CalledProcessError) as exc:
        print(f"发布失败：{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
