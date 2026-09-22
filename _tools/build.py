#!/usr/bin/env python3
"""Build, validate, publish, and clean the Advanced Macroeconomics notes."""

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SECTION_ROOT = PROJECT_ROOT / "sections"
BUILD_ROOT = PROJECT_ROOT / "_build"
MACTEX_BIN = os.environ.get("MACTEX_BIN")
LATEXMK = str(Path(MACTEX_BIN) / "latexmk") if MACTEX_BIN else "latexmk"
XELATEX = str(Path(MACTEX_BIN) / "xelatex") if MACTEX_BIN else "xelatex"
MAIN_TEX = PROJECT_ROOT / "AdvMacroNote_Sun.tex"
MAIN_BUILD_DIR = BUILD_ROOT / "book"
MAIN_PDF = MAIN_BUILD_DIR / "AdvMacroNote_Sun.pdf"
MAIN_SYNCTEX = MAIN_BUILD_DIR / "AdvMacroNote_Sun.synctex.gz"
MAIN_LOG = MAIN_BUILD_DIR / "AdvMacroNote_Sun.log"
CONTENT_MANIFEST = PROJECT_ROOT / "_config" / "core" / "content-map.tex"

PART_DIRECTORY = re.compile(r"^part-(\d{2})$")
CHAPTER_NUMBER = re.compile(r"\\def\\StandaloneChapterNumber\s*\{(\d{1,2})\}")
COURSE_SETUP = re.compile(
    r"\\def\\StandaloneCourseSetup\s*\{(\\UseMacro(?:I|II)Course)\}"
)
UNSAFE_TEX_PATH = re.compile(r"[%#{}\\]")

XELATEX_COMMAND = [
    XELATEX, "-synctex=1", "-interaction=nonstopmode", "-halt-on-error",
    "-file-line-error",
]

BUILD_SUFFIXES = {
    ".aux", ".bbl", ".bcf", ".blg", ".fdb_latexmk", ".fls", ".log",
    ".lof", ".lot", ".nav", ".out", ".snm", ".toc", ".vrb", ".xdv",
    ".acn", ".acr", ".alg", ".glg", ".glo", ".gls", ".idx", ".ilg",
    ".ind", ".ist",
}
BUILD_NAME_ENDINGS = (".run.xml", ".bbl-SAVE-ERROR", ".synctex(busy)")


class BuildError(RuntimeError):
    pass


def require_executable(path: str) -> None:
    if shutil.which(path) is None:
        raise BuildError(f"找不到命令：{path}；请配置 PATH 或 MACTEX_BIN")


def run(command: list[str], cwd: Path, *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print(f"+ {shlex.join(command)}", flush=True)
    return subprocess.run(
        command, cwd=cwd, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )


def ensure_nonempty(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise BuildError(f"没有生成有效文件：{path.relative_to(PROJECT_ROOT)}")


def publish(build_file: Path, destination: Path) -> None:
    ensure_nonempty(build_file)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(build_file, destination)


def source_metadata(path: Path, kind: str) -> tuple[str, str]:
    source = path.read_text(encoding="utf-8")
    is_appendix = r"\def\StandaloneIsAppendix" in source
    if kind == "chapter" and is_appendix:
        raise BuildError(f"Chapter 目录中出现 Appendix：{path.relative_to(PROJECT_ROOT)}")
    if kind == "appendix" and not is_appendix:
        raise BuildError(f"Appendix 缺少 StandaloneIsAppendix：{path.relative_to(PROJECT_ROOT)}")
    number_match = CHAPTER_NUMBER.search(source)
    course_match = COURSE_SETUP.search(source)
    if not number_match or not course_match:
        raise BuildError(
            f"源码缺少 StandaloneChapterNumber 或 StandaloneCourseSetup："
            f"{path.relative_to(PROJECT_ROOT)}"
        )
    return f"{int(number_match.group(1)):02d}", course_match.group(1)


def chapter_directories() -> list[Path]:
    return sorted(
        path for path in SECTION_ROOT.iterdir()
        if path.is_dir() and PART_DIRECTORY.fullmatch(path.name)
    )


def collect_numbered_sources(kind: str) -> dict[str, Path]:
    directories = chapter_directories() if kind == "chapter" else [SECTION_ROOT / "appendices"]
    sources: dict[str, Path] = {}
    for directory in directories:
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.tex")):
            if path.name == "part.tex":
                continue
            number, _course = source_metadata(path, kind)
            if number in sources:
                first = sources[number].relative_to(PROJECT_ROOT)
                second = path.relative_to(PROJECT_ROOT)
                raise BuildError(f"{kind}-{number} 对应多个文件：{first}、{second}")
            sources[number] = path
    return sources


def tex_input(path: Path) -> str:
    relative = path.relative_to(PROJECT_ROOT).as_posix()
    if UNSAFE_TEX_PATH.search(relative):
        raise BuildError(f"路径含有不受支持的 TeX 特殊字符：{relative}")
    source = path.with_suffix("").relative_to(PROJECT_ROOT).as_posix()
    return rf"    \input{{{source}}}%"


def write_content_manifest() -> None:
    chapters = collect_numbered_sources("chapter")
    appendices = collect_numbered_sources("appendix")
    if not chapters:
        raise BuildError("sections/part-XX 中没有找到 Chapter 源码")
    lines = [
        "% 本文件由 _tools/build.py 自动维护；文件改名后运行 make all。",
        r"\newcommand{\InputProjectContent}{%",
    ]
    active_course = ""
    seen_chapters: set[str] = set()
    for part_dir in chapter_directories():
        part_file = part_dir / "part.tex"
        if not part_file.is_file():
            raise BuildError(f"缺少 Part 入口：{part_file.relative_to(PROJECT_ROOT)}")
        part_sources = [
            (number, path) for number, path in chapters.items()
            if path.parent == part_dir
        ]
        if not part_sources:
            raise BuildError(f"{part_dir.name} 中没有 Chapter 源码")
        part_sources.sort()
        course_setups = {source_metadata(path, "chapter")[1] for _number, path in part_sources}
        if len(course_setups) != 1:
            raise BuildError(f"{part_dir.name} 内的课程配置不一致")
        course_setup = course_setups.pop()
        if active_course and active_course != course_setup:
            lines.append(r"    \clearpage")
        if active_course != course_setup:
            lines.append(f"    {course_setup}")
            active_course = course_setup
        lines.append(tex_input(part_file))
        for number, path in part_sources:
            lines.append(tex_input(path))
            seen_chapters.add(number)
    if seen_chapters != set(chapters):
        raise BuildError("有 Chapter 未归入 part-XX 目录")
    if appendices:
        appendix_part = SECTION_ROOT / "appendices" / "part.tex"
        if not appendix_part.is_file():
            raise BuildError("缺少 sections/appendices/part.tex")
        appendix_setups = {source_metadata(path, "appendix")[1] for path in appendices.values()}
        if len(appendix_setups) != 1:
            raise BuildError("Appendix 的课程配置不一致")
        appendix_setup = appendix_setups.pop()
        lines.extend((r"    \clearpage", f"    {appendix_setup}", r"    \BeginBookAppendix"))
        lines.append(tex_input(appendix_part))
        for _number, path in sorted(appendices.items()):
            lines.append(tex_input(path))
        lines.append(r"    \EndBookAppendix")
    lines.append("}")
    content = "\n".join(lines) + "\n"
    if not CONTENT_MANIFEST.exists() or CONTENT_MANIFEST.read_text(encoding="utf-8") != content:
        CONTENT_MANIFEST.write_text(content, encoding="utf-8")
        print(f"已更新内容清单：{CONTENT_MANIFEST.relative_to(PROJECT_ROOT)}")


def verify_references() -> None:
    ensure_nonempty(MAIN_LOG)
    log = MAIN_LOG.read_text(encoding="utf-8", errors="replace")
    problems = (
        r"There were undefined references", r"There were undefined citations",
        r"(?:Reference|Citation) .+ undefined", r"Rerun to get cross-references right",
        r"Label\(s\) may have changed",
    )
    if any(re.search(pattern, log) for pattern in problems):
        raise BuildError("完整构建后仍有未解决的引用，请检查 _build/book/AdvMacroNote_Sun.log")


def build_all() -> None:
    require_executable(LATEXMK)
    write_content_manifest()
    MAIN_BUILD_DIR.mkdir(parents=True, exist_ok=True)
    run([
        LATEXMK, "-xelatex", "-synctex=1", "-interaction=nonstopmode",
        "-halt-on-error", "-file-line-error", "-outdir=_build/book", MAIN_TEX.name,
    ], PROJECT_ROOT)
    ensure_nonempty(MAIN_PDF)
    ensure_nonempty(MAIN_SYNCTEX)
    verify_references()
    print("完整构建完成：_build/book/AdvMacroNote_Sun.pdf（根目录发布版未修改）")


def normalize_chapter(value: str) -> str:
    if not value or not value.isdecimal():
        raise BuildError("请指定章节号，例如 make chap 03")
    number = int(value)
    if not 1 <= number <= 99:
        raise BuildError("章节号必须在 01–99 之间")
    return f"{number:02d}"


def find_chapter(value: str) -> Path:
    number = normalize_chapter(value)
    chapters = collect_numbered_sources("chapter")
    if number not in chapters:
        raise BuildError(f"找不到 Chapter {number}")
    return chapters[number]


def build_chapter(value: str) -> None:
    require_executable(XELATEX)
    chapter_file = find_chapter(value)
    part_dir = BUILD_ROOT / "book" / chapter_file.parent.name
    part_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="advanced-macro-chapter-") as temporary:
        temporary_dir = Path(temporary)
        run([
            *XELATEX_COMMAND, f"-jobname={chapter_file.stem}",
            f"-output-directory={temporary_dir}", chapter_file.name,
        ], chapter_file.parent)
        publish(temporary_dir / f"{chapter_file.stem}.pdf", part_dir / f"{chapter_file.stem}.pdf")
        publish(
            temporary_dir / f"{chapter_file.stem}.synctex.gz",
            part_dir / f"{chapter_file.stem}.synctex.gz",
        )
    print(f"单章构建完成：{part_dir.relative_to(PROJECT_ROOT)}（一次 XeLaTeX）")


def remove_matching_intermediates() -> int:
    removed = 0
    for path in PROJECT_ROOT.rglob("*"):
        if path.is_file() and (path.suffix in BUILD_SUFFIXES or path.name.endswith(BUILD_NAME_ENDINGS)):
            path.unlink()
            removed += 1
    if BUILD_ROOT.exists():
        shutil.rmtree(BUILD_ROOT)
        removed += 1
    for directory in PROJECT_ROOT.rglob("__pycache__"):
        if directory.is_dir():
            shutil.rmtree(directory)
            removed += 1
    return removed


def remove_paths(paths: set[Path]) -> int:
    removed = 0
    for path in sorted(paths):
        if path.is_dir():
            shutil.rmtree(path)
            removed += 1
        elif path.exists():
            path.unlink()
            removed += 1
    return removed


def rednote_outputs() -> set[Path]:
    paths: set[Path] = set()
    for issue in (PROJECT_ROOT / "rednote").glob("part-*"):
        for pattern in ("poster-*.pdf", "poster-*.png", "poster-*.synctex.gz"):
            paths.update(issue.glob(pattern))
        pages = issue / "pages"
        if pages.exists():
            paths.add(pages)
    paths.add(BUILD_ROOT / "posts")
    return paths


def stale_outputs() -> set[Path]:
    paths = set(PROJECT_ROOT.rglob(".DS_Store")) | set(PROJECT_ROOT.rglob("__pycache__"))
    for path in SECTION_ROOT.rglob("*"):
        if path.is_file() and (path.suffix == ".pdf" or path.name.endswith(".synctex.gz")):
            paths.add(path)
    return paths


def all_deliverables() -> set[Path]:
    paths = rednote_outputs()
    for root in (SECTION_ROOT, PROJECT_ROOT / "logo"):
        for path in root.rglob("*"):
            if path.is_file() and (path.suffix == ".pdf" or path.name.endswith(".synctex.gz")):
                paths.add(path)
    return paths


def clean(mode: str) -> None:
    removed = remove_matching_intermediates()
    if mode in ("stale", "all"):
        removed += remove_paths(stale_outputs())
    if mode in ("rednote", "all"):
        removed += remove_paths(rednote_outputs())
    if mode == "all":
        removed += remove_paths(all_deliverables())
    labels = {
        "basic": "构建中间产物；已发布 PDF 与 PNG 已保留",
        "stale": "中间产物与陈旧文件；有效输出已保留",
        "rednote": "中间产物与 Rednote 输出；Rednote 源码已保留",
        "all": "全部可重建产物；源码与资源已保留",
    }
    print(f"已删除 {removed} 项：{labels[mode]}。")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("action", choices=("all", "chapter", "sync", "clean"))
    parser.add_argument("values", nargs="*")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.action == "all":
            build_all()
        elif args.action == "chapter":
            build_chapter(args.values[0] if args.values else "")
        elif args.action == "sync":
            write_content_manifest()
        elif args.action == "clean":
            mode = args.values[0] if args.values else "basic"
            if mode not in ("basic", "stale", "rednote", "all"):
                raise BuildError("clean 模式只能是 basic、stale、rednote 或 all")
            clean(mode)
    except (BuildError, subprocess.CalledProcessError) as exc:
        print(f"构建失败：{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
