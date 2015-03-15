TARGETS = aeten-submodules.sh
SHELL_LOG = @@SHELL-LOG@@
SHELL_LOG_SCRIPT = aeten-shell-log/aeten-shell-log.sh

all: $(TARGETS)

%.sh: %.sh.template
	sed -e '/$(SHELL_LOG)/r $(SHELL_LOG_SCRIPT)' -e '/$(SHELL_LOG)/d' $< > $@
	chmod a+rx $@

clean:
	rm -f $(TARGETS)
