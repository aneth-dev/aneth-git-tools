SHELL_LOG_DIR := ./aeten-shell-log
INSTALL_DIR := .
TARGETS = aeten-submodules.sh
SHELL_LOG = @@SHELL-LOG-INCLUDE@@
SHELL_LOG_SCRIPT = $(SHELL_LOG_DIR)/aeten-shell-log.sh
check = @$(SHELL_LOG_SCRIPT) check

all: $(TARGETS)

%.sh: %.sh.template
	$(check) -m 'Check submodule checkout' test -f $(SHELL_LOG_SCRIPT)
	$(check) -m 'Insert shell login for standalone use' sed -e '/$(SHELL_LOG)/r $(SHELL_LOG_SCRIPT)' -e \'s/$(SHELL_LOG)/let SHELL_LOG_INCLUDE=1/\' $< \> $@
	$(check) -m 'Update .gitignore' "{ test -f .gitignore &&  grep '^$@$$' .gitignore; } || sed --quiet --regexp-extended -e '1i $@' -e 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' $< >> .gitignore"
	$(check) -m 'Set exec flag to $@' chmod a+rx $@

.gitignore: $(TARGETS)
	$(check) -m 'Generate .gitignore' for target in $^; do\
		./$$target $(INSTALL_DIR); \
		grep \'^$${target}\' .gitignore \|\| sed --quiet --regexp-extended -e \'1i $${target}\' -e \'s/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p\' $${target}.template \>\> .gitignore \
	done

install: $(TARGETS)
	for target in $^; do\
		./$${target} $(INSTALL_DIR); \
	done

clean:
	$(check) -m 'Remove .gitignore and targets' rm -f .gitignore $(TARGETS)
	$(check) -m 'Remove symlinks' find . -mindepth 1 -maxdepth 1 -type l -exec rm -f {} '\;'
