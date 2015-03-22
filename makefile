AETEN_CLI_DIR := ./aeten-cli
prefix := /usr/local
bin := $(prefix)/bin
lib := $(prefix)/lib
include_cli := true

SCRIPT = aeten-submodules.sh
COMMANDS = $(shell bash -c '. $$(pwd)/$(SCRIPT) ; __api $(SCRIPT)')
LINKS = $(addprefix $(bin)/,$(COMMANDS))
LIB_DIR = $(shell readlink -f "$$(test '$(lib)' = '$$(pwd)' && echo $(lib) || echo $(lib))")

CUR_DIR = $(shell readlink -f "$(CURDIR)")
AETEN_CLI = \#@@AETEN-CLI-INCLUDE@@
AETEN_CLI_SCRIPT = $(AETEN_CLI_DIR)/aeten-cli.sh

check = @$(AETEN_CLI_SCRIPT) check

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
ifeq (true,$(include_cli))
	$(check) -m 'Check submodule checkout' test -f $(AETEN_CLI_SCRIPT)
	$(check) -m 'Install lib $@ with aeten-cli inclusion' "sed -e '/$(AETEN_CLI)/r $(AETEN_CLI_SCRIPT)' -e 's/$(AETEN_CLI)/let AETEN_CLI_INCLUDE=1/' -e '/^#!\/bin\/sh/d' $< > $@"
else
	$(check) -m 'Install lib $@' cp $< $@
endif
	$(check) -m 'Set exec flag to $@' chmod a+rx $@
endif

$(LINKS): $(LIB_DIR)/$(SCRIPT)
	$(check) -m 'Install symlink $@' ln -s $< $@
