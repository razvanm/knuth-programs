FILES := $(shell cat programs.txt)

all: programs.html programs.txt $(FILES)

programs.html:
	curl -O --silent https://www-cs-faculty.stanford.edu/~knuth/programs.html

programs.txt: programs.html
	grep 'a href="programs/' $< | sed -r -n 's|.*(programs/[^"]+)".*|\1|p' > $@

programs/%:
	curl --output $@ --silent $(addprefix https://www-cs-faculty.stanford.edu/~knuth/,$@)
