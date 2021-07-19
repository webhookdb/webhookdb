check-version:
	@node tools/checkversion

install: check-version
	yarn install

run: check-version
	yarn run develop

run-network: check-version
	yarn run develop-network

build: check-version
	yarn build

test: check-version
	yarn run test

prettier: check-version
	yarn run prettier
sort-imports:
	yarn run sort-imports
fmt: prettier sort-imports
eslint: check-version
	yarn run eslint
lint: eslint
lint-fix:
	yarn run eslint-fix
check: prettier sort-imports eslint test
