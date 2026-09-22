#!/usr/bin/env python3
"""Minimal public command dispatcher for the project Makefile."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TOOLS_ROOT = PROJECT_ROOT / "_tools"


class ProjectCommandError(RuntimeError):
    pass


def run(script: str, *arguments: str) -> None:
    subprocess.run([sys.executable, str(TOOLS_ROOT / script), *arguments], cwd=PROJECT_ROOT, check=True)


def require_number(values: list[str], command: str) -> str:
    if len(values) != 2 or not values[1].isdecimal():
        raise ProjectCommandError(f"用法：make {command} 03")
    return values[1]


def dispatch(values: list[str]) -> None:
    if not values:
        values = ["all"]
    command = values[0].lower()
    if command == "all" and len(values) == 1:
        run("build.py", "all")
    elif command == "chap":
        run("build.py", "chapter", require_number(values, "chap"))
    elif command == "post":
        run("rednote.py", "poster", require_number(values, "post"))
    else:
        raise ProjectCommandError(
            f"未知命令：{' '.join(values)}；仅支持 make all、make chap 03、make post 03"
        )


def main() -> int:
    try:
        dispatch(sys.argv[1:])
    except (ProjectCommandError, subprocess.CalledProcessError) as exc:
        print(f"命令失败：{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
