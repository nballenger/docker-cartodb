.PHONY: build help
.DEFAULT_GOAL := help

buildconf?=DEFAULT

help:
	@echo "Usage: make [OPTION] [buildconf=<NAME>]"

build:
	@echo "Build command, buildconf is $(buildconf)"
