AETEN_CLI_DIR := ./aneth-cli
prefix := /usr/local
bin := $(prefix)/bin
lib := $(prefix)/lib
include_cli := true

SUBMODULES = aneth-cli
SUBMODULES_SCRIPT = aneth-submodules.sh
SUBMODULES_COMMANDS = $(shell $$(pwd)/$(SUBMODULES_SCRIPT) __api)
SUBMODULES_LINKS = $(addprefix $(bin)/,$(SUBMODULES_COMMANDS))
REMOTE_SCRIPT = aneth-remote.sh
REMOTE_COMMANDS = $(shell $$(pwd)/$(REMOTE_SCRIPT) __api)
REMOTE_LINKS = $(addprefix $(bin)/,$(REMOTE_COMMANDS))
LIB_DIR = $(shell readlink -f "$$(test '$(lib)' = '$$(pwd)' && echo $(lib) || echo $(lib))")

CUR_DIR = $(shell readlink -f "$(CURDIR)")
AETEN_CLI = \#@@AETEN-CLI-INCLUDE@@
AETEN_CLI_SCRIPT = $(AETEN_CLI_DIR)/aneth-cli.sh

check = $(AETEN_CLI_SCRIPT) check
git_submodule = "bash -c '. $(AETEN_CLI_SCRIPT) && aneth_cli_import $(AETEN_CLI_SCRIPT) all && . ./$(SUBMODULES_SCRIPT) && git-submodule-${1}'"
git_remote = ". $(AETEN_CLI_SCRIPT) '&&' aneth_cli_import $(AETEN_CLI_SCRIPT) all '&&' . ./$(REMOTE_SCRIPT) '&&'"

ifeq ($(LIB_DIR),$(CUR_DIR))
GITIGNORE = .gitignore
endif

.PHONY: all clean install uninstall ${SUBMODULES}
all: ${SUBMODULES}

%.sh: %.sh.template

.gitignore: $(SUBMODULES_SCRIPT) $(REMOTE_SCRIPT)
	@$(check) -m 'Update .gitignore' "echo .gitignore > .gitignore && sed --quiet --regexp-extended 's/^(git-[[:alnum:]_-]+)\s*\(\)\s*\{/\1/p' $< >> .gitignore"

install: $(SUBMODULES_LINKS) $(REMOTE_LINKS) $(GITIGNORE)

uninstall:
	@test "$(CUR_DIR)" = "$(LIB_DIR)" || $(check) -m 'Uninstall lib' rm -f $(addprefix $(LIB_DIR)/,$(SUBMODULES_SCRIPT) $(REMOTE_SCRIPT))
	@$(check) -m 'Uninstall symlinks' rm -f $(SUBMODULES_LINKS) $(REMOTE_LINKS)

${SUBMODULES}: ${AETEN_CLI_SCRIPT}
	@$(check) -m 'Reset submodule $@' $(call git_submodule,reset-shallow $@)

${AETEN_CLI_SCRIPT}:
	git submodule update --init aneth-cli

clean:
	@test -f .gitignore && $(check) -m 'Remove .gitignore' rm -f .gitignore || true

ifneq ($(LIB_DIR),$(CUR_DIR)) # Prevent circular dependency
$(LIB_DIR)/%: %
ifeq (true,$(include_cli))
	@$(check) -m 'Check submodule checkout' test -f $(AETEN_CLI_SCRIPT)
ifeq (./aneth-cli,$(AETEN_CLI_DIR))
	@$(check) -l warn -m "Check submodule checkout revision" $(call git_submodule,check aneth-cli); true
endif
	@$(check) -m 'Install lib $@ with aneth-cli inclusion' "sed -e '/$(AETEN_CLI)/r $(AETEN_CLI_SCRIPT)' -e '/$(AETEN_CLI)/a \\\naneth_cli_import \$${0} all' -e '/$(AETEN_CLI)/d' $< > $@"
else
	@$(check) -m 'Install lib $@' cp $< $@
endif
	@$(check) -m 'Set exec flag to $@' chmod a+rx $@
endif

$(SUBMODULES_LINKS): $(LIB_DIR)/$(SUBMODULES_SCRIPT)
	@$(check) -m 'Install symlink $@' ln -s $< $@

$(REMOTE_LINKS): $(LIB_DIR)/$(REMOTE_SCRIPT)
	@$(check) -m 'Install symlink $@' ln -s $< $@
