SHELL_LOG_DIR := ./aeten-shell-log
prefix := /usr/local
lib := $(prefix)/lib
include_log_shell := true

SCRIPT = aeten-submodules.sh
COMMANDS = $(shell bash -c '. $$(pwd)/$(SCRIPT) ; __api $(SCRIPT)')
LINKS = $(addprefix $(prefix)/bin/,$(COMMANDS))
LIB_DIR = $(shell readlink -f "$$(test '$(lib)' = '$$(pwd)' && echo $(lib) || echo $(lib))")

CUR_DIR = $(shell readlink -f "$(CURDIR)")
SHELL_LOG = \#@@SHELL-LOG-INCLUDE@@
SHELL_LOG_SCRIPT = $(SHELL_LOG_DIR)/aeten-shell-log.sh

check = @$(SHELL_LOG_SCRIPT) check

.PHONY: all install uninstall
all: .gitignore

%.sh: %.sh.template

.gitignore: $(SCRIPT)
	$(check) -m 'Update .gitignore' "echo .gitignore > .gitignore && sed --quiet --regexp-extended 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' $< >> .gitignore"

install: $(LINKS)

uninstall:
	$(check) -m 'Uninstall lib' rm -f $(filter-out $(CUR_DIR)/$(SCRIPT),$(LIB_DIR)/$(SCRIPT))
	$(check) -m 'Uninstall symlinks' rm -f $(LINKS)

clean:
	$(check) -m 'Remove .gitignore' rm -f .gitignore

ifneq ($(LIB_DIR),$(CUR_DIR)) # Prevent circular dependency
$(LIB_DIR)/%: %
	echo include_log_shell=$(include_log_shell)
ifeq (true,$(include_log_shell))
	$(check) -m 'Check submodule checkout' test -f $(SHELL_LOG_SCRIPT)
	$(check) -m 'Install lib $@ with aeten-shell-log inclusion' "sed -e '/$(SHELL_LOG)/r $(SHELL_LOG_SCRIPT)' -e 's/$(SHELL_LOG)/let SHELL_LOG_INCLUDE=1/' -e '/^#!\/bin\/sh/d' $< > $@"
else
	$(check) -m 'Install lib $@' cp $< $@
endif
	$(check) -m 'Set exec flag to $@' chmod a+rx $@
endif

$(LINKS): $(LIB_DIR)/$(SCRIPT)
	$(check) -m 'Install symlink $@' ln -s $< $@
