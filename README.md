# XMU_AdvMacro_Note_SUN

这里是老艺人古法匠心打造的 readme 文件，为本 XMU_AdvMacro_Note_SUN 项目提供使用说明。

</br>

## 事先说明

- 开源本项目的主要目的是
    - 方便他人获取最新笔记，即在根目录的 PDF 文件
    - 方便他人提供笔记建议，欢迎提交 GitHub issue

- **! 将本笔记当作模板并非主要目的 !**
    - 如果你想当作模板，请详细研究项目架构

- 本人先完成《高宏 II》笔记后再增加《高宏 I》笔记，并非正常高宏学习顺序
    - 《高宏 I》笔记来自于助教工作
    - 《高宏 II》笔记来自于上课学习

</br>

## 项目结构

```
├── .vscode/      # 我的配置，请仔细察看
│
├── _assets/               # 相关附件
├── _build/                # 编译产出：book、posts、visuals
├── _tools/                # 编译程序
│
├── _config/               # 配置文件
│   ├── core/              # 无需更改配置
│   └── xxx/               # 可调参数配置
│
├── sections/              # 笔记正文
│   └── part-xx/           # 分部内容
│       └── chapte-xx/     # 分章内容
│
├── logo/                  # 产出图标
├── rednote/               # 产出小红书
│
├── AdvMacroNote_Sun.tex   # 核心入口
├── AdvMacroNote_Sun_vX.Y.Z.pdf # 正式发布版，仅由 make release 更新
│
├── references.bib         # 参考文献
└── Makefile               # 编译命令
```

</br>

## 获取方式

### 方法一

如果你只是想要 PDF 笔记，那么[请点此下载](https://github.com/econsun/XMU_AdvMacro_Note_SUN/releases/download/v1.0.0/AdvMacroNote_Sun_v1.0.0.pdf)。

### 方法二

点击 GitHub 页面中的 “code” 绿色按钮，找到下载 zip 压缩包

### 方法三

如果你的设备中已安装 Git 工具，直接在你想存放本项目的路径打开命令行并输入：

```bash
git clone git@github.com:econsun/XMU_AdvMacro_Note_SUN.git
```

</br>

## 使用方式

- 我个人使用方式是 VS Code + LaTeX workshop + Makefile 三大工具
    - 找到笔记文件进行修改
    - 点击 LW 插件提供的 build LaTeX project 即可编译当前笔记
    - 对根目录 AdvMacroNote_Sun.tex 使用 build LaTeX project 编译可得完整笔记
    - 除此之外，Makefile 提供了三类命令行编译方式

```bash
# 编译完整笔记
make
make all

# 编译章笔记
make chap 03

# 完整编译后生成封面与章笔记 PNG
make post 03

# 更新正式版并发布到 GitHub
make release VERSION=v2.1.0
```

日常的 `make`、`make all`、Build LaTeX project 和 View PDF 都使用 `_build/book/AdvMacroNote_Sun.pdf`，不会修改根目录正式版。只有 `make release VERSION=vX.Y.Z` 会完整编译、把根目录正式版更新为 `AdvMacroNote_Sun_vX.Y.Z.pdf`、提交、创建标签、推送到 `main`、创建 GitHub Release，并自动更新方法一的版本下载链接后提交 `doc: update readme`。发布前要求工作区干净、本地 `main` 与 `origin/main` 同步，并已通过 GitHub CLI 登录。

</br>

## 致谢

感谢俚霖，如果没有她常伴心头，这份笔记就不会如此完整。

感谢所有同学，你们让这份笔记变得有意义。
