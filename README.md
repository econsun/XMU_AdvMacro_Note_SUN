# Advanced Macroeconomics Notes

## 目录约定

`AdvMacroNote_Sun.tex` 是整书唯一入口。`sections/part-XX/` 保存正文，`rednote/part-XX/` 保存对应海报，两者按相同 Part 结构组织。`_config/` 集中保存 LaTeX 配置，`_tools/` 集中保存构建脚本，`_assets/` 集中保存图片与 MATLAB 源文件，旧的补充材料归档在 `_archive/`，所有可重建产物进入 `_build/`。

经常修改的文件集中在三处：正文位于 `sections/`，海报位于 `rednote/`，项目配置位于 `_config/`。根层的 `99 INFO.tex`、`cover-main.tex`、`cover-part.tex` 与四个 `setting-*.tex` 可直接修改；无需日常修改的实现统一位于 `_config/core/`。Logo 的可调参数仍位于 `logo/settings.tex` 和 `logo/poster-settings.tex`。

## 自动发现规则

整书顺序不依赖 Chapter 的完整文件名。`_tools/build.py` 从每个源码中的 `\StandaloneChapterNumber` 与 `\StandaloneCourseSetup` 读取编号和课程配置，再自动生成 `_config/core/content-map.tex`。因此可以修改 `chapter-XX-` 后面的标题，也可以在 `part-XX` 之间移动 Chapter；运行 `make all` 时映射会自动更新。

Rednote 以 `\RednoteChapterNumber` 与正文配对。`make post XX` 会对齐对应海报的 Part、文件名与正文相对路径。项目文件不写入机器相关的绝对路径。

## 常用命令

```sh
make all      # 构建整书 AdvMacroNote_Sun.pdf
make chap 03  # 构建 Chapter 03 PDF
make post 03  # 构建 Chapter 03 Poster PDF 与 PNG
```

## LaTeX Workshop

Chapter、Appendix 和 Poster 都是真正的独立根文件，保存时只构建当前文件；`AdvMacroNote_Sun.tex` 使用 `make all`。编辑器通过 `latex-workshop.latex.texDirs` 直接解析已经由 `\input` 载入的 `_config/setting-cmds.tex`，项目不再生成或维护补全 JSON。修改命令后保存文件即可刷新候选；若扩展仍保留旧缓存，执行一次 `Developer: Reload Window`。
