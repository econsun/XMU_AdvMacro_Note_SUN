#!/usr/bin/env python3
"""Build the standalone AMaN logo variants with local MacTeX."""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
LOGO_ROOT = PROJECT_ROOT / "logo"
VARIANT_ROOT = LOGO_ROOT / "variants"
OUTPUT_ROOT = LOGO_ROOT / "output"
BUILD_ROOT = PROJECT_ROOT / "_build" / "logo"
MACTEX_BIN = os.environ.get("MACTEX_BIN")
XELATEX = str(Path(MACTEX_BIN) / "xelatex") if MACTEX_BIN else "xelatex"

VARIANT_ALIASES = {
    "horizontal": "horizontal", "hori": "horizontal", "hor": "horizontal", "h": "horizontal",
    "vertical": "vertical", "ver": "vertical", "v": "vertical",
    "axis": "axis", "chart": "axis", "graph": "axis",
    "text": "text", "type": "text", "word": "text",
    "poster": "poster", "post": "poster", "long": "poster",
    "aman": "aman", "mark": "aman", "name": "aman",
}
PROFILE_ALIASES = {"default": "default", "xmu": "default", "accent": "accent"}
PROFILES = {
    "default": ("InstitutionMark", "SecondaryText"),
    "accent": ("VolumeOneAccent", "VolumeTwoAccent"),
}
SOURCE_NAMES = {
    "horizontal": "01-horizontal.tex",
    "vertical": "02-vertical.tex",
    "axis": "03-chart.tex",
    "text": "04-text.tex",
    "aman": "05-aman.tex",
    "poster": "06-poster.tex",
}


class LogoBuildError(RuntimeError):
    pass


def resolve_variant(value: str) -> Path:
    """按别名、编号、完整文件干名或编号后的名称寻找版本入口。"""
    canonical = VARIANT_ALIASES.get(value, value)
    if canonical in SOURCE_NAMES:
        return VARIANT_ROOT / SOURCE_NAMES[canonical]
    candidates = sorted(VARIANT_ROOT.glob("[0-9][0-9]-*.tex"))
    matches = [
        path for path in candidates
        if value in (path.stem, path.stem[:2], path.stem.split("-", 1)[1])
    ]
    if len(matches) == 1:
        return matches[0]
    raise LogoBuildError(f"找不到唯一 Logo 版本：{value}")


def parse_arguments(values: list[str]) -> tuple[Path, str]:
    values = [value for value in values if value]
    source, profile = VARIANT_ROOT / SOURCE_NAMES["horizontal"], "default"
    seen_variant = seen_profile = False
    for raw_value in values:
        value = raw_value.lower()
        if value in PROFILE_ALIASES and not seen_profile:
            profile, seen_profile = PROFILE_ALIASES[value], True
        elif not seen_variant:
            source, seen_variant = resolve_variant(value), True
        else:
            raise LogoBuildError(
                "用法：python3 _tools/logo.py [版本名称|编号] [default|accent]"
            )
    return source, profile


def verify_log(path: Path) -> None:
    content = path.read_text(encoding="utf-8", errors="replace")
    patterns = (
        r"^!", r"LaTeX(?: Font)? Warning:", r"Package .+ Warning:",
        r"Overfull \\hbox", r"Underfull \\hbox", r"Missing character:",
    )
    if any(re.search(pattern, content, re.MULTILINE) for pattern in patterns):
        raise LogoBuildError(f"Logo 编译日志存在错误或警告：{path.name}")


def build(source_path: Path, profile: str) -> Path:
    if shutil.which(XELATEX) is None:
        raise LogoBuildError(f"找不到命令：{XELATEX}；请配置 PATH 或 MACTEX_BIN")
    primary, secondary = PROFILES[profile]
    suffix = "" if profile == "default" else f"-{profile}"
    job_name = f"{source_path.stem}{suffix}"
    source = source_path.name
    tex_entry = (
        rf"\def\LogoVariantPrimaryColor{{{primary}}}"
        rf"\def\LogoVariantSecondaryColor{{{secondary}}}"
        rf"\input{{{source}}}"
    )
    command = [
        XELATEX, "-synctex=1", "-interaction=nonstopmode", "-halt-on-error",
        "-file-line-error", f"-jobname={job_name}", "-output-directory=../../_build/logo", tex_entry,
    ]
    BUILD_ROOT.mkdir(parents=True, exist_ok=True)
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    print(f"+ {shlex.join(command)}", flush=True)
    subprocess.run(command, cwd=VARIANT_ROOT, check=True)
    built_pdf = BUILD_ROOT / f"{job_name}.pdf"
    built_synctex = BUILD_ROOT / f"{job_name}.synctex.gz"
    pdf_path = OUTPUT_ROOT / f"{job_name}.pdf"
    synctex_path = OUTPUT_ROOT / f"{job_name}.synctex.gz"
    log_path = BUILD_ROOT / f"{job_name}.log"
    if not built_pdf.is_file() or built_pdf.stat().st_size == 0:
        raise LogoBuildError(f"没有生成有效文件：{built_pdf.name}")
    verify_log(log_path)
    shutil.copy2(built_pdf, pdf_path)
    if built_synctex.is_file():
        shutil.copy2(built_synctex, synctex_path)
    print(f"Logo 已生成：logo/output/{pdf_path.name}")
    return pdf_path


def main() -> int:
    try:
        source, profile = parse_arguments(sys.argv[1:])
        build(source, profile)
    except (LogoBuildError, subprocess.CalledProcessError) as exc:
        print(f"Logo 构建失败：{exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
