.DEFAULT_GOAL := build

REPONAME = telota/mattermost
VERSION = $(shell grep MATTERMOST_VERSION= Dockerfile | cut -d '=' -f 2 | cut -d ' ' -f 1)

.PHONY: pull-base
pull-base:
	docker pull $(shell egrep "^FROM " Dockerfile | cut -d ' ' -f 2)

.PHONY: build
build: pull-base
	docker build -t $(REPONAME):$(VERSION) .

.PHONY: release
release: build
	git tag -f $(VERSION)
	git tag -f latest
	git push -f upstream $(VERSION) latest
