# todo_infra — install symlinks for the TMUX-Claude manager on this machine.
#
#   make install   wire up hooks, tmux.conf, and project skills (idempotent)
#   make uninstall  remove the symlinks this Makefile created
#
# The repo holds canonical copies (claude_hooks/, tmux.conf, claude_skills/);
# install symlinks them to the locations Claude Code / tmux expect:
#   ~/.claude/hooks/*.sh           <- settings.json references these
#   ~/.tmux.conf
#   <todo-root>/.claude/skills     <- discovered by dir-hierarchy walk on launch
#
# Idempotent: a correct existing symlink is left alone; a real file in the way
# is backed up to <path>.bak before the symlink is created.

# Self-locating: REPO is the dir holding this Makefile (the .infra repo), and
# the todo-system root is always its parent — so paths track wherever the repo
# is checked out (e.g. ~/main/todo vs ~/main/doc/todo) with no per-machine edit.
REPO    := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
HOOKS   := $(REPO)/claude_hooks
SKILLS  := $(REPO)/claude_skills
AGENTS  := $(REPO)/claude_agents
TMUXCONF:= $(REPO)/tmux.conf
TODO_CLAUDE_MD := $(REPO)/CLAUDE.todo.md

CLAUDE_HOOKS_DIR := $(HOME)/.claude/hooks
TODO_ROOT        := $(realpath $(REPO)/..)
TODO_CLAUDE_DIR  := $(TODO_ROOT)/.claude
HOME_TMUXCONF    := $(HOME)/.tmux.conf

HOOK_NAMES := tmux-helpers.sh tmux-move-done.sh tmux-move-perms.sh \
              tmux-move-running.sh tmux-relayout.sh tmux-save-session-id.sh

# link <src> <dst>: idempotent symlink with backup of any real file in the way
define LINK
	if [ -L "$(2)" ] && [ "$$(readlink "$(2)")" = "$(1)" ]; then \
		echo "ok    $(2)"; \
	else \
		if [ -e "$(2)" ] || [ -L "$(2)" ]; then \
			mv "$(2)" "$(2).bak"; echo "backup $(2) -> $(2).bak"; \
		fi; \
		ln -sfn "$(1)" "$(2)"; echo "link  $(2) -> $(1)"; \
	fi
endef

.PHONY: install uninstall
install:
	@mkdir -p "$(CLAUDE_HOOKS_DIR)" "$(TODO_CLAUDE_DIR)"
	@for n in $(HOOK_NAMES); do \
		$(call LINK,$(HOOKS)/$$n,$(CLAUDE_HOOKS_DIR)/$$n) \
	done
	@$(call LINK,$(TMUXCONF),$(HOME_TMUXCONF))
	@$(call LINK,$(SKILLS),$(TODO_CLAUDE_DIR)/skills)
	@$(call LINK,$(AGENTS),$(TODO_CLAUDE_DIR)/agents)
	@$(call LINK,$(TODO_CLAUDE_MD),$(TODO_ROOT)/CLAUDE.md)
	@echo "note: $(TODO_ROOT)/CLAUDE.local.md is per-machine (not tracked); create it for machine-specific cross-system areas."
	@echo "install: done"

uninstall:
	@for n in $(HOOK_NAMES); do \
		if [ -L "$(CLAUDE_HOOKS_DIR)/$$n" ]; then rm "$(CLAUDE_HOOKS_DIR)/$$n"; echo "rm $(CLAUDE_HOOKS_DIR)/$$n"; fi; \
	done
	@if [ -L "$(HOME_TMUXCONF)" ]; then rm "$(HOME_TMUXCONF)"; echo "rm $(HOME_TMUXCONF)"; fi
	@if [ -L "$(TODO_CLAUDE_DIR)/skills" ]; then rm "$(TODO_CLAUDE_DIR)/skills"; echo "rm $(TODO_CLAUDE_DIR)/skills"; fi
	@if [ -L "$(TODO_CLAUDE_DIR)/agents" ]; then rm "$(TODO_CLAUDE_DIR)/agents"; echo "rm $(TODO_CLAUDE_DIR)/agents"; fi
	@if [ -L "$(TODO_ROOT)/CLAUDE.md" ]; then rm "$(TODO_ROOT)/CLAUDE.md"; echo "rm $(TODO_ROOT)/CLAUDE.md"; fi
	@echo "uninstall: done"
