#!/usr/bin/env python3
"""Sync, build, and export Rednote material paired with note chapters."""

from __future__ import annotations

import re
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path

from build import collect_numbered_sources

PROJECT_ROOT = Path(__file__).resolve().parent.parent
REDNOTE_ROOT = PROJECT_ROOT / "rednote"
BUILD_ROOT = PROJECT_ROOT / "_build"
TEMPLATE_FILE = REDNOTE_ROOT / "poster-template.txt"
MAIN_PDF = PROJECT_ROOT / "AdvMacroNote_Sun.pdf"
MACTEX_BIN = os.environ.get("MACTEX_BIN")
XELATEX = str(Path(MACTEX_BIN) / "xelatex") if MACTEX_BIN else "xelatex"

CHAPTER_ALIASES = ("chapter", "chap", "ch", "c")
OPERATION_ALIASES = {
    "new": "new", "create": "new", "init": "new",
    "poster": "poster", "cover": "poster",
    "pages": "pages", "page": "pages", "export": "pages",
    "build": "build", "both": "build", "make": "build",
    "all": "all", "prepare": "all",
    "sync": "sync",
    "help": "help", "usage": "help",
}
AUTO_INFO_START = "% --- 自动信息开始：由 make 更新，请勿手动修改 ---"
AUTO_INFO_END = "% --- 自动信息结束 ---"
POSTER_RECIPE_LINE = "% !LW recipe = XeLaTeX poster (once)"
POSTER_DOCUMENT_CLASS = r"\documentclass[UTF8,fontset=none]{ctexart}"


class RednoteError(RuntimeError):
    pass


def require_command(name: str) -> None:
    if shutil.which(name) is None:
        raise RednoteError(f"找不到命令：{name}")


def require_mactex(path: str) -> None:
    if shutil.which(path) is None:
        raise RednoteError(f"找不到命令：{path}；请配置 PATH 或 MACTEX_BIN")


def run(command: list[str], cwd: Path, *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print(f"+ {shlex.join(command)}", flush=True)
    return subprocess.run(
        command, cwd=cwd, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )


def ensure_nonempty(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise RednoteError(f"没有生成有效文件：{path.relative_to(PROJECT_ROOT)}")


def pdf_pixel_size(pdf_path: Path, dpi: int) -> tuple[int, int]:
    """按 PDF 的真实页面尺寸计算整数像素，避免渲染器在底边补一行白色像素。"""
    require_command("pdfinfo")
    output = run(["pdfinfo", pdf_path.name], pdf_path.parent, capture=True).stdout
    match = re.search(r"^Page size:\s+([0-9.]+) x ([0-9.]+) pts", output, re.MULTILINE)
    if not match:
        raise RednoteError(f"无法读取 PDF 页面尺寸：{pdf_path.relative_to(PROJECT_ROOT)}")
    width_pt, height_pt = map(float, match.groups())
    return round(width_pt * dpi / 72), round(height_pt * dpi / 72)


def normalize_number(value: str) -> str:
    if not value or not value.isdecimal():
        raise RednoteError("请指定 Chapter 编号，例如 01")
    number = int(value)
    if not 1 <= number <= 99:
        raise RednoteError("Chapter 编号必须在 01–99 之间")
    return f"{number:02d}"


def parse_chapter(values: list[str]) -> str:
    if not values:
        raise RednoteError("缺少 Chapter 编号")
    if len(values) == 1 and values[0].isdecimal():
        return normalize_number(values[0])
    if len(values) == 1:
        joined = re.fullmatch(r"(?:chapter|chap|ch|c)(\d{1,2})", values[0].lower())
        if joined:
            return normalize_number(joined.group(1))
    if len(values) == 2 and values[0].lower() in CHAPTER_ALIASES:
        return normalize_number(values[1])
    if values[0].lower() in ("part", "p") or re.fullmatch(r"p(?:art)?\d+", values[0].lower()):
        raise RednoteError("Rednote 已取消 Part 模式；请输入 Chapter 编号")
    raise RednoteError("目标可写为 01 或 chapter 01")


def parse_request(values: list[str]) -> tuple[str, str]:
    values = [value for value in values if value]
    if not values:
        return "help", ""
    first = values[0].lower()
    if first in OPERATION_ALIASES:
        operation = OPERATION_ALIASES[first]
        target_values = values[1:]
    else:
        # make rn 03：数字默认代表 Chapter，并完成项目、海报和正文图片。
        operation = "build"
        target_values = values
    if operation in ("help", "all", "sync"):
        if target_values:
            raise RednoteError(f"{operation} 后不需要编号")
        return operation, ""
    return operation, parse_chapter(target_values)


def numbered_chapters() -> dict[str, Path]:
    try:
        return collect_numbered_sources("chapter")
    except RuntimeError as exc:
        raise RednoteError(str(exc)) from exc


def poster_sources() -> dict[str, Path]:
    sources: dict[str, Path] = {}
    pattern = re.compile(r"\\newcommand\{\\RednoteChapterNumber\}\{(\d{2})\}")
    for path in sorted(REDNOTE_ROOT.glob("part-*/*.tex")):
        match = pattern.search(path.read_text(encoding="utf-8"))
        if not match:
            continue
        number = match.group(1)
        if number in sources:
            raise RednoteError(f"Rednote Chapter {number} 对应多个文件")
        sources[number] = path
    return sources


def managed_poster_name(chapter_path: Path) -> str:
    suffix = re.sub(r"^chapter-\d{2}-?", "", chapter_path.stem)
    return f"poster-{chapter_metadata_number(chapter_path)}{f'-{suffix}' if suffix else ''}.tex"


def chapter_metadata_number(chapter_path: Path) -> str:
    source = chapter_path.read_text(encoding="utf-8")
    match = re.search(r"\\def\\StandaloneChapterNumber\s*\{(\d{1,2})\}", source)
    if not match:
        raise RednoteError(f"Chapter 缺少编号：{chapter_path.relative_to(PROJECT_ROOT)}")
    return f"{int(match.group(1)):02d}"


def extract_braced_command(source: str, command: str) -> str:
    match = re.search(rf"\\{re.escape(command)}\s*\{{", source)
    if not match:
        raise RednoteError(f"源码中找不到 \\{command}{{...}}")
    start, depth, index = match.end(), 1, match.end()
    while index < len(source):
        character = source[index]
        if character == "\\":
            index += 2
            continue
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return source[start:index].strip()
        index += 1
    raise RednoteError(f"\\{command} 的花括号没有闭合")


def chapter_metadata(number: str) -> dict[str, str]:
    chapters = numbered_chapters()
    if number not in chapters:
        raise RednoteError(f"找不到 Chapter {number}")
    chapter_path = chapters[number]
    source = chapter_path.read_text(encoding="utf-8")
    title = extract_braced_command(source, "chapter")
    course_setup = r"\UseMacroIICourse" if r"\UseMacroIICourse" in source else r"\UseMacroICourse"
    return {
        "CHAPTER_NUMBER": number,
        "CHAPTER_DISPLAY_NUMBER": str(int(number)),
        "CHAPTER_TITLE": title,
        "ISSUE_DATE": date.today().isoformat(),
        "COURSE_SETUP": course_setup,
        "SOURCE_FILE": chapter_path.relative_to(PROJECT_ROOT).as_posix(),
        "PART_DIRECTORY": chapter_path.parent.name,
        "POSTER_NAME": managed_poster_name(chapter_path).removesuffix(".tex"),
    }


def poster_info_block(metadata: dict[str, str]) -> str:
    """生成 poster-XX.tex 内可安全刷新的自动信息区。"""
    return "\n".join((
        AUTO_INFO_START,
        rf"\newcommand{{\RednoteChapterNumber}}{{{metadata['CHAPTER_NUMBER']}}}",
        rf"\newcommand{{\RednoteChapterDisplayNumber}}{{{metadata['CHAPTER_DISPLAY_NUMBER']}}}",
        rf"\newcommand{{\RednoteSourceChapterTitle}}{{{metadata['CHAPTER_TITLE']}}}",
        rf"\newcommand{{\RednoteIssueDate}}{{{metadata['ISSUE_DATE']}}}",
        rf"\newcommand{{\RednoteCourseSetup}}{{{metadata['COURSE_SETUP']}}}",
        rf"\newcommand{{\RednoteSourceFile}}{{{metadata['SOURCE_FILE']}}}",
        AUTO_INFO_END,
    ))


def update_poster_source(number: str, issue_dir: Path, metadata: dict[str, str]) -> Path:
    """更新自动信息区，保留标题、字号等全部手动设置。"""
    existing_source = poster_sources().get(number)
    poster_source = issue_dir / f"{metadata['POSTER_NAME']}.tex"
    if existing_source and existing_source != poster_source:
        poster_source.parent.mkdir(parents=True, exist_ok=True)
        existing_source.replace(poster_source)
        print(
            f"已对齐海报路径：{existing_source.relative_to(PROJECT_ROOT)} -> "
            f"{poster_source.relative_to(PROJECT_ROOT)}"
        )
    info_block = poster_info_block(metadata)
    if not poster_source.exists():
        template = TEMPLATE_FILE.read_text(encoding="utf-8")
        poster_source.write_text(
            template.replace("@@POSTER_FILE@@", poster_source.name)
            .replace("@@POSTER_INFO@@", info_block), encoding="utf-8"
        )
        return poster_source
    source = poster_source.read_text(encoding="utf-8")
    pattern = re.compile(
        rf"^{re.escape(AUTO_INFO_START)}$.*?^{re.escape(AUTO_INFO_END)}$",
        re.MULTILINE | re.DOTALL,
    )
    if pattern.search(source):
        updated = pattern.sub(lambda _match: info_block, source, count=1)
    else:
        lines = source.splitlines()
        insertion = next(
            (index + 1 for index, line in enumerate(lines)
             if line.startswith(r"\documentclass")),
            0,
        )
        lines[insertion:insertion] = [info_block, ""]
        updated = "\n".join(lines) + "\n"
    # 每个海报都是真正的根文档；这样 Workshop 不会向上回退到整书入口。
    body_lines = [
        line for line in updated.splitlines()
        if not line.startswith("% !TeX root =")
        and not line.startswith("% !TeX LW recipe =")
        and not line.startswith("% !LW recipe =")
        and line != POSTER_DOCUMENT_CLASS
    ]
    updated = "\n".join((POSTER_RECIPE_LINE, POSTER_DOCUMENT_CLASS, *body_lines)) + "\n"
    poster_source.write_text(updated, encoding="utf-8")
    return poster_source


def issue_directory(number: str) -> Path:
    return REDNOTE_ROOT / chapter_metadata(number)["PART_DIRECTORY"]


def create_issue(number: str) -> tuple[Path, bool]:
    metadata = chapter_metadata(number)
    issue_dir = issue_directory(number)
    issue_dir.mkdir(parents=True, exist_ok=True)
    expected_source = issue_dir / f"{metadata['POSTER_NAME']}.tex"
    created = not expected_source.exists() and number not in poster_sources()
    poster_source = update_poster_source(number, issue_dir, metadata)
    print(f"{'已创建' if created else '已更新'}海报源码：{poster_source.relative_to(PROJECT_ROOT)}")
    return issue_dir, created


def verify_log(log_path: Path, label: str) -> None:
    ensure_nonempty(log_path)
    log = log_path.read_text(encoding="utf-8", errors="replace")
    patterns = (
        r"^!", r"LaTeX Font Warning:", r"Package .+ Warning:",
        r"Missing character:", r"Overfull \\hbox",
    )
    if any(re.search(pattern, log, re.MULTILINE) for pattern in patterns):
        raise RednoteError(f"{label}日志存在错误或警告：{log_path.relative_to(PROJECT_ROOT)}")


def build_poster(number: str, issue_dir: Path) -> None:
    require_mactex(XELATEX)
    require_command("pdftoppm")
    poster_name = chapter_metadata(number)["POSTER_NAME"]
    build_name = poster_name
    build_dir = BUILD_ROOT / build_name
    build_dir.mkdir(parents=True, exist_ok=True)
    relative_output = os.path.relpath(build_dir, issue_dir)
    command = [
        XELATEX, "-synctex=1", "-interaction=nonstopmode", "-halt-on-error",
        "-file-line-error", f"-jobname={build_name}",
        f"-output-directory={relative_output}", f"{poster_name}.tex",
    ]
    # 海报没有交叉引用，一次 XeLaTeX 即可得到最终输出。
    run(command, issue_dir)
    poster_pdf = build_dir / f"{build_name}.pdf"
    poster_synctex = build_dir / f"{build_name}.synctex.gz"
    ensure_nonempty(poster_pdf)
    ensure_nonempty(poster_synctex)
    verify_log(build_dir / f"{build_name}.log", "海报")
    poster_png = build_dir / f"{poster_name}.png"
    poster_png.unlink(missing_ok=True)
    width_px, height_px = pdf_pixel_size(poster_pdf, 300)
    poster_pdf_relative = poster_pdf.relative_to(PROJECT_ROOT)
    poster_prefix_relative = (build_dir / poster_name).relative_to(PROJECT_ROOT)
    run([
        "pdftoppm", "-png", "-r", "300", "-f", "1", "-l", "1",
        "-scale-to-x", str(width_px), "-scale-to-y", str(height_px),
        "-singlefile", str(poster_pdf_relative), str(poster_prefix_relative),
    ], PROJECT_ROOT)
    ensure_nonempty(poster_png)
    print(f"海报已生成：{poster_png.relative_to(PROJECT_ROOT)}（300 DPI）")


def build_main_document() -> None:
    run([sys.executable, "_tools/build.py", "all"], PROJECT_ROOT)
    ensure_nonempty(MAIN_PDF)


def pdf_destinations() -> dict[str, int]:
    require_command("pdfinfo")
    output = run(["pdfinfo", "-dests", MAIN_PDF.name], PROJECT_ROOT, capture=True).stdout
    destinations: dict[str, int] = {}
    pattern = re.compile(r'^\s*(\d+)\s+\[.*\]\s+"([^"]+)"\s*$')
    for line in output.splitlines():
        match = pattern.match(line)
        if match:
            destinations[match.group(2)] = int(match.group(1))
    return destinations


def pdf_page_count() -> int:
    output = run(["pdfinfo", MAIN_PDF.name], PROJECT_ROOT, capture=True).stdout
    match = re.search(r"^Pages:\s+(\d+)\s*$", output, re.MULTILINE)
    if not match:
        raise RednoteError("无法读取主 PDF 的总页数")
    return int(match.group(1))


def next_structural_page(destinations: dict[str, int], first_page: int, total_pages: int) -> int:
    pages = [
        page for name, page in destinations.items()
        if re.fullmatch(r"(?:chapter|part)\.\d+", name) and page > first_page
    ]
    return min(pages) if pages else total_pages + 1


def export_pages(
    number: str, issue_dir: Path, *, rebuild_main: bool = True,
    destinations: dict[str, int] | None = None, total_pages: int | None = None,
) -> None:
    require_command("pdftoppm")
    if rebuild_main:
        build_main_document()
    destinations = destinations or pdf_destinations()
    total_pages = total_pages or pdf_page_count()
    destination_name = f"chapter.{int(number)}"
    if destination_name not in destinations:
        raise RednoteError(f"PDF 中缺少目标：{destination_name}")
    first_page = destinations[destination_name]
    last_page = next_structural_page(destinations, first_page, total_pages) - 1
    if last_page < first_page:
        raise RednoteError("计算出的导出页码范围无效")
    poster_name = chapter_metadata(number)["POSTER_NAME"]
    output_dir = BUILD_ROOT / poster_name / "pages"
    output_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="advanced-macro-rednote-") as temporary:
        temporary_prefix = Path(temporary) / "page"
        run([
            "pdftoppm", "-png", "-r", "300", "-f", str(first_page),
            "-l", str(last_page), MAIN_PDF.name, str(temporary_prefix),
        ], PROJECT_ROOT)
        pages = sorted(
            Path(temporary).glob("page-*.png"),
            key=lambda path: int(path.stem.rsplit("-", 1)[1]),
        )
        expected = last_page - first_page + 1
        if len(pages) != expected:
            raise RednoteError(f"预期导出 {expected} 页，实际得到 {len(pages)} 页")
        for old_image in output_dir.glob("*.png"):
            old_image.unlink()
        width = len(str(expected))
        for index, source in enumerate(pages, start=1):
            source.replace(output_dir / f"{index:0{width}d}.png")
    print(f"Chapter {number} 的正文页已导出到 {output_dir.relative_to(PROJECT_ROOT)}")


def prepare_all_chapters() -> Path:
    chapters = numbered_chapters()
    if not chapters:
        raise RednoteError("没有找到 Chapter 源文件")
    build_main_document()
    destinations = pdf_destinations()
    total_pages = pdf_page_count()
    for number in chapters:
        issue_dir = create_issue(number)[0]
        build_poster(number, issue_dir)
        export_pages(
            number, issue_dir, rebuild_main=False,
            destinations=destinations, total_pages=total_pages,
        )
    print(f"全部 {len(chapters)} 个 Chapter 的帖子素材已更新")
    return REDNOTE_ROOT


def sync_all_chapters() -> None:
    chapters = numbered_chapters()
    if not chapters:
        raise RednoteError("没有找到 Chapter 源文件")
    for number in chapters:
        create_issue(number)
    print(f"已同步 {len(chapters)} 个 Chapter 的 Rednote 入口")


def main() -> int:
    try:
        operation, number = parse_request(sys.argv[1:])
        if operation == "help":
            raise RednoteError("用法：make post 03")
        if operation == "sync":
            sync_all_chapters()
            return 0
        if operation == "all":
            prepare_all_chapters()
            return 0
        issue_dir = create_issue(number)[0]
        if operation in ("poster", "build"):
            build_poster(number, issue_dir)
        if operation in ("pages", "build"):
            export_pages(number, issue_dir)
    except (RednoteError, subprocess.CalledProcessError) as exc:
        print(f"Rednote 失败：{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
