PYTHON ?= python3
PROJECT_CLI := _tools/project.py
FORWARD_COMMANDS := chap post

.DEFAULT_GOAL := all
.PHONY: all release $(FORWARD_COMMANDS)

# Make 只保留开发构建、单章、帖子和正式发布四个公开入口。
all:
	@if [ -z "$(MAKECMDGOALS)" ] || [ "$@" = "$(firstword $(MAKECMDGOALS))" ]; then \
		$(PYTHON) $(PROJECT_CLI) all; \
	fi

# 只有此入口可更新根目录正式版并发布到 GitHub。
release:
	@$(PYTHON) _tools/release.py "$(VERSION)"

$(FORWARD_COMMANDS):
	@if [ "$@" = "$(firstword $(MAKECMDGOALS))" ]; then \
		$(PYTHON) $(PROJECT_CLI) $(MAKECMDGOALS); \
	fi

# 空格后的参数由此吸收，但只执行第一个目标。
%:
	@if [ "$@" = "$(firstword $(MAKECMDGOALS))" ]; then \
		$(PYTHON) $(PROJECT_CLI) $(MAKECMDGOALS); \
	fi
