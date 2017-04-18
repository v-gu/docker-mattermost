.DEFAULT_GOAL := build

REPONAME = funkyfuture/mattermost
VERSION = $(shell grep MATTERMOST_VERSION= Dockerfile | cut -d '=' -f 2 | cut -d ' ' -f 1)

.PHONY: pull-base
pull-base:
	docker pull $(shell egrep "^FROM " Dockerfile | cut -d ' ' -f 2)

.PHONY: build
build: pull-base
	docker build -t $(REPONAME):$(VERSION) .
