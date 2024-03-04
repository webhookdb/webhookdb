
fmt:
	npm run fmt-fix
	npm run lint-fix
check:
	npm run fmt
	npm run lint
test:
	npm test

start:
	npm run dev

env-%:
	@if [ -z '${${*}}' ]; then echo 'ERROR: variable $* not set' && exit 1; fi
cmd-exists-%:
	@hash $(*) > /dev/null 2>&1 || \
		(echo "ERROR: '$(*)' must be installed and available on your PATH."; exit 1)
