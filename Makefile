prerequisites:

prerequisites-mac: prerequisites
	brew install --cask snowflake-snowsql
	ln -s /Applications/SnowSQL.app/Contents/MacOS/snowsql /usr/local/bin/snowsql
	snowsql -v

install:
	bundle install
cop:
	bundle exec rubocop
fix:
	bundle exec rubocop --autocorrect-all
fmt: fix

up:
	docker-compose up -d
down:
	docker-compose stop

release:
	bundle exec foreman start release

run:
	CUSTOMER_SKIP_AUTHENTICATION=true bundle exec foreman start web
run-with-verification:
	bundle exec foreman start web
run-workers:
	bundle exec foreman start worker
ngrok:
	ngrok http -subdomain webhookdb-${USER} 18001
run-with-ngrok:
	WEBHOOKDB_API_URL=https://webhookdb-${USER}.ngrok.io make run

migrate:
	bundle exec rake db:migrate
migrate-to-%:
	bundle exec rake db:migrate[$(*)]

reset-db:
	bundle exec rake db:reset

reset-sidekiq-redis:
	bundle exec rake sidekiq:reset

test:
	RACK_ENV=test bundle exec rspec spec/
	@./bin/notify "Tests finished"
testf:
	RACK_ENV=test bundle exec rspec spec/ --fail-fast --seed=1
	@./bin/notify "Tests finished"
migrate-test:
	RACK_ENV=test bundle exec rake db:drop_tables_and_replication_databases
	RACK_ENV=test bundle exec rake db:migrate
wipe-test-db:
	RACK_ENV=test bundle exec rake db:wipe_tables_and_drop_replication_databases
recreate-test-db:
	docker-compose stop test_db
	docker-compose rm -f test_db
	docker-compose up -d test_db
	make migrate-test

fixture-full:
	RACK_ENV=development bundle exec rake fixture:full

integration-test:
	INTEGRATION_TESTS=true RACK_ENV=development bundle exec rspec integration/
	@./bin/notify "Integration tests finished"
integration-test-task:
	INTEGRATION_TESTS=true bundle exec rake specs:integration

annotate:
	LOG_LEVEL=info bundle exec rake annotate
docs-replicators:
	LOG_LEVEL=warn bundle exec rake docs:replicators['../docs/_integrations']

psql: cmd-exists-pgcli
	pgcli postgres://webhookdb:webhookdb@localhost:18005/webhookdb
psql-test: cmd-exists-pgcli
	pgcli postgres://webhookdb:webhookdb@localhost:18006/webhookdb_test

pry:
	@bundle exec pry

message-render: env-MESSAGE
	@bundle exec rake message:render[$(MESSAGE)]
message-render-html: env-MESSAGE
	@bundle exec rake message:render[$(MESSAGE)] > message.html
	open message.html
	sleep 3
	rm message.html

docker-build: ## Build the local docker image.
	@docker build -f docker/Dockerfile -t webhookdb \
		--build-arg GIT_SHA=`git rev-list --abbrev-commit -1 HEAD` \
		--build-arg RELEASED_AT=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		.

docker-run-%: ## Run the built local webhookdb image (docker-build target). Use -web, -worker, and -release.
	docker run \
		--init \
		-p 18001:18001 \
		-e PORT=18001 \
		--env-file=.env.development \
		--env-file=.env.development.docker \
		webhookdb $(*)

dockerhub-run-%: ## Download the webhookdb docker image from Dockerhub and run it.
	docker run \
		--init \
		-p 18001:18001 \
		-e PORT=18001 \
		--env-file=.env.development \
		--env-file=.env.development.docker \
		webhookdb/webhookdb:latest $(*)

VERSION := `cat lib/webhookdb/version.rb | grep 'VERSION =' | cut -d '"' -f2`

gem-build:
ifeq ($(strip $(VERSION)),)
	echo "Could not parse VERSION"
else
	git tag $(VERSION)
	gem build webhookdb.gemspec
	gem push webhookdb-$(VERSION).gem
	git push origin $(VERSION)
endif

env-%:
	@if [ -z '${${*}}' ]; then echo 'ERROR: variable $* not set' && exit 1; fi

cmd-exists-%:
	@hash $(*) > /dev/null 2>&1 || \
		(echo "ERROR: '$(*)' must be installed and available on your PATH."; exit 1)
