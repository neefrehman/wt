.PHONY: lint check

check: lint

lint:
	@echo "==> Syntax check (zsh -n)"
	zsh -n wt.zsh
	@echo "==> ShellCheck (advisory, using --shell=bash for approximation due to no zsh support)"
	-shellcheck --shell=bash wt.zsh
