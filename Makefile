
.PHONY: build

build:
	@find -name '*.coffee' | xargs coffee -c

