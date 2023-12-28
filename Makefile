FILES := $(shell cat programs.txt)
WEB_FILES := $(wildcard programs/*.w)
WEB_FILES_BASE := $(basename $(WEB_FILES))
TEX_FILES := $(addsuffix .tex,$(WEB_FILES_BASE))
C_FILES := $(addsuffix .c,$(WEB_FILES_BASE))

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

%.pdf: %.tex
	pdftex -output-directory=$(dir $@) $<

%.c: %.w
	ctangle $< - $@
