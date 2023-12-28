FILES := $(shell cat programs.txt)
WEB_FILES := $(wildcard programs/*.w)
WEB_FILES_BASE := $(basename $(WEB_FILES))
CH_FILES := $(wildcard programs/*.ch)
CH_FILES_BASE := $(basename $(CH_FILES))
TEX_FILES := $(addsuffix .tex,$(WEB_FILES_BASE) $(CH_FILES_BASE))
C_FILES := $(addsuffix .c,$(WEB_FILES_BASE) $(CH_FILES_BASE))

all: programs.html programs.txt $(TEX_FILES) $(C_FILES)
update: $(FILES)

programs.html:
	curl -O --silent https://www-cs-faculty.stanford.edu/~knuth/programs.html

# TODO: remove the fix for de-bruijn-dlx.w after Don updates the programs.html.
programs.txt: programs.html
	cat $< | sed 's|<a href="programs/ian-dlx.w">DE-BRUIJN-DLX</a>|<a href="programs/de-bruijn-dlx.w">DE-BRUIJN-DLX</a>|' | grep 'a href="programs/' | sed -r -n 's|.*(programs/[^"]+)".*|\1|p' > $@

$(FILES):
	curl --output $@ --silent $(addprefix https://www-cs-faculty.stanford.edu/~knuth/,$@)

%.tex: %.w
	cweave $< - $@

%.c: %.w
	ctangle $< - $@

%.tex: %.ch
	cweave $(filter %.w,$^) $(filter %.ch,$^) $@

%.c: %.ch
	ctangle $(filter %.w,$^) $(filter %.ch,$^) $@

%.pdf: %.tex
	pdftex -output-directory=$(dir $@) $<

deps:
	for i in $(WEB_FILES); do for j in $$(echo $(filter-out krom-count.ch,CH_FILES) | fmt -1 | grep $$(echo $$i | cut -d '.' -f 1)); do echo $${j%.ch}.tex $${j%.ch}.c: $$i $$j; done; done > Makefile.deps

# This is a special case that doesn't follow the pattern of having a .w that
# is a prefix of the .ch file.
programs/krom-count.tex programs/krom-count.c: programs/horn-count.w programs/krom-count.ch

-include Makefile.deps
