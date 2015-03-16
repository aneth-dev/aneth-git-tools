SHELL_LOG_DIR := ./aeten-shell-log
INSTALL_DIR := .
TARGETS = aeten-submodules.sh
SHELL_LOG = @@SHELL-LOG@@
SHELL_LOG_SCRIPT = $(SHELL_LOG_DIR)/aeten-shell-log.sh

all: $(TARGETS)

%.sh: %.sh.template
	test -f $(SHELL_LOG_SCRIPT)
	sed -e '/$(SHELL_LOG)/r $(SHELL_LOG_SCRIPT)' -e '/$(SHELL_LOG)/d' $< > $@
	grep '^$@$$' .gitignore || sed --quiet --regexp-extended -e '1i $@' -e 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' $< >> .gitignore 
	chmod a+rx $@

.gitignore: $(TARGETS)
	for target in $^; do\
		./$$target $(INSTALL_DIR); \
		grep '^$${target}' .gitignore || sed --quiet --regexp-extended -e '1i $${target}' -e 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' $${target}.template >> .gitignore \
	done

install: $(TARGETS)
	for target in $^; do\
		./$${target} $(INSTALL_DIR); \
	done

clean:
	rm -f .gitignore $(TARGETS)
	find . -mindepth 1 -maxdepth 1 -type l -exec rm -f {} \;
