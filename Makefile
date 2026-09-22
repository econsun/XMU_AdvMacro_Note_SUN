PYTHON ?= python3
PROJECT_CLI := _tools/project.py
FORWARD_COMMANDS := chap post

.DEFAULT_GOAL := all
.PHONY: all $(FORWARD_COMMANDS)

# Make 只保留整书、单章和单张海报三个公开入口。
all:
	@if [ -z "$(MAKECMDGOALS)" ] || [ "$@" = "$(firstword $(MAKECMDGOALS))" ]; then \
		$(PYTHON) $(PROJECT_CLI) all; \
	fi

$(FORWARD_COMMANDS):
	@if [ "$@" = "$(firstword $(MAKECMDGOALS))" ]; then \
		$(PYTHON) $(PROJECT_CLI) $(MAKECMDGOALS); \
	fi

# 空格后的参数由此吸收，但只执行第一个目标。
%:
	@if [ "$@" = "$(firstword $(MAKECMDGOALS))" ]; then \
		$(PYTHON) $(PROJECT_CLI) $(MAKECMDGOALS); \
	fi
