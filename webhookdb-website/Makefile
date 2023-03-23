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
check: prettier sort-imports eslint

markdown-%: ## Convert the named blog post to HTML and write to stdout.
	@$(shell yarn bin remark) --use remark-frontmatter --use remark-html blog/$(*)/index.md

wpmd-%: ## Convert the named blog post to HTML suitable for posting on a Wordpress blog.
	@echo "<!-- wp:html -->" > temp.txt
	@make markdown-$(*) >> temp.txt
	@echo "<p><em>This was originally on the WebhookDB blog, at <a href=\"https://webhookdb.com/blog/FIXME\">https://webhookdb.com/blog/FIXME</a></a>. If you have any questions, please leave a comment or  <a href=\"mailto:hello@webhookdb.com\">get in touch</a>!</em></p>" >> temp.txt
	@echo "<!-- /wp:html -->" >> temp.txt
	@cat temp.txt | pbcopy
	@rm temp.txt

optimize-blog-images: check-version
	@node ./tools/optimize-blog-images.js
