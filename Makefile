FILES := $(shell cat programs.txt)
WEB_FILES := $(wildcard programs/*.w)
WEB_FILES_BASE := $(basename $(WEB_FILES))
TEX_FILES := $(addsuffix .tex,$(WEB_FILES_BASE))
C_FILES := $(addsuffix .c,$(WEB_FILES_BASE))

all: programs.html programs.txt $(FILES) $(TEX_FILES) $(C_FILES)

programs.html:
	curl -O --silent https://www-cs-faculty.stanford.edu/~knuth/programs.html

programs.txt: programs.html
	grep 'a href="programs/' $< | sed -r -n 's|.*(programs/[^"]+)".*|\1|p' > $@

programs/%:
	curl --output $@ --silent $(addprefix https://www-cs-faculty.stanford.edu/~knuth/,$@)

%.tex: %.w
	cweave $< - $@

%.pdf: %.tex
	pdftex -output-directory=$(dir $@) $<

%.c: %.w
	ctangle $< - $@
