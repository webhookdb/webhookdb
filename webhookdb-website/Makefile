check-version:
	@node tools/checkversion

install: check-version
	yarn install

run: check-version
	gatsby develop

run-network: check-version
	gatsby develop -H 0.0.0.0

build: check-version
	gatsby build

fmt: check-version
	yarn run format

test: check-version
	yarn run test

reset: check-version
	rm -rf node_modules
	rm yarn.lock
	yarn install
