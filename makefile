SHELL_LOG_DIR := ./aeten-shell-log
INSTALL_DIR := .
TARGETS = aeten-submodules.sh
SHELL_LOG = @@SHELL-LOG@@
SHELL_LOG_SCRIPT = $(SHELL_LOG_DIR)/aeten-shell-log.sh

all: $(TARGETS)

%.sh: %.sh.template
	test -f $(SHELL_LOG_SCRIPT)
	sed -e '/$(SHELL_LOG)/r $(SHELL_LOG_SCRIPT)' -e '/$(SHELL_LOG)/d' $< > $@
	chmod a+rx $@

install: $(TARGETS)
	./$< $(INSTALL_DIR)

clean:
	rm -f $(TARGETS)
	find . -mindepth 1 -maxdepth 1 -type l -exec rm -f {} \;
