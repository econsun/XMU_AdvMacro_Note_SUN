#!/usr/bin/env python3
"""编译各章 poster-XX.tex，并生成统一缩略总览图。"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path


def compose_overview(posters: list[Path], output: Path) -> None:
    """不用 montage 的字体标签功能，直接把缩略图按 4 列拼接。"""
    import rednote as manager

    with tempfile.TemporaryDirectory(prefix="advanced-macro-poster-gallery-") as temporary:
        temporary_dir = Path(temporary)
        rows = []
        for row_index in range(0, len(posters), 4):
            row = temporary_dir / f"row-{row_index // 4 + 1}.png"
            command = ["magick"]
            for poster in posters[row_index:row_index + 4]:
                command.extend([
                    "(", str(poster), "-thumbnail", "300x400",
                    "-background", "#25272A", "-gravity", "center",
                    "-extent", "332x432", ")",
                ])
            command.extend(["+append", str(row)])
            manager.run(command, manager.PROJECT_ROOT)
            rows.append(row)
        manager.run(["magick", *(str(row) for row in rows), "-append", str(output)], manager.PROJECT_ROOT)


def main() -> int:
    import rednote as manager

    manager.require_command("magick")
    posters = []
    for number in manager.numbered_chapters():
        if "reuse" in sys.argv[1:] or "--reuse" in sys.argv[1:]:
            issue_dir = manager.issue_directory(number)
        else:
            issue_dir = manager.create_issue(number)[0]
            manager.build_poster(number, issue_dir)
        output_name = manager.chapter_metadata(number)["OUTPUT_NAME"]
        posters.append(manager.BUILD_ROOT / "posts" / output_name / "pages" / "00-cover.png")
        manager.ensure_nonempty(posters[-1])

    output_dir = manager.BUILD_ROOT / "posts" / "overview"
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / "poster-overview.png"
    output.unlink(missing_ok=True)
    compose_overview(posters, output)
    manager.ensure_nonempty(output)
    print(f"Poster 总览已生成：{output.relative_to(manager.PROJECT_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
