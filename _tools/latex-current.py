#!/usr/bin/env python3
"""LaTeX Workshop current-file builder using only relative TeX inputs."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MACTEX_BIN = os.environ.get("MACTEX_BIN")
XELATEX = str(Path(MACTEX_BIN) / "xelatex") if MACTEX_BIN else "xelatex"
CHAPTER_OUTPUT_ROOT = PROJECT_ROOT / "_build" / "book"


def build_directory(source_path: Path) -> Path:
    return CHAPTER_OUTPUT_ROOT / source_path.parent.name


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--passes", type=int, choices=(1, 2), default=1)
    parser.add_argument("source")
    args = parser.parse_args()
    cwd = Path.cwd()
    source = Path(args.source).name
    source_path = cwd / source
    if not source_path.is_file():
        print(f"找不到当前 TeX 文件：{source}", file=sys.stderr)
        return 1
    if shutil.which(XELATEX) is None:
        print(f"找不到命令：{XELATEX}；请配置 PATH 或 MACTEX_BIN", file=sys.stderr)
        return 1
    try:
        cwd.relative_to(PROJECT_ROOT)
    except ValueError:
        print("当前文件不在 AdvMacroNote 项目内", file=sys.stderr)
        return 1
    build_dir = build_directory(source_path)
    build_dir.mkdir(parents=True, exist_ok=True)
    relative_output = os.path.relpath(build_dir, cwd)
    command = [
        XELATEX, "-synctex=1", "-interaction=nonstopmode", "-halt-on-error",
        "-file-line-error", f"-jobname={source_path.stem}",
        f"-output-directory={relative_output}", source,
    ]
    try:
        for _ in range(args.passes):
            subprocess.run(command, cwd=cwd, check=True)
        pdf = build_dir / f"{source_path.stem}.pdf"
        synctex = build_dir / f"{source_path.stem}.synctex.gz"
        if not pdf.is_file() or pdf.stat().st_size == 0:
            raise RuntimeError(f"没有生成有效 PDF：{pdf.relative_to(PROJECT_ROOT)}")
        if not synctex.is_file() or synctex.stat().st_size == 0:
            raise RuntimeError(f"没有生成有效 SyncTeX：{synctex.relative_to(PROJECT_ROOT)}")
        print(f"当前文件构建完成：{pdf.relative_to(PROJECT_ROOT)}")
    except (subprocess.CalledProcessError, RuntimeError) as exc:
        print(f"当前文件构建失败：{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
