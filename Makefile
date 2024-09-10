build: build-heroku-18 build-heroku-20 build-heroku-22

build-heroku-18:
	@echo "Building nginx in Docker for heroku-18..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-18" -w /buildpack heroku/heroku:18-build scripts/build_nginx /buildpack/nginx-heroku-18.tgz

build-heroku-20:
	@echo "Building nginx in Docker for heroku-20..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-20" -w /buildpack heroku/heroku:20-build scripts/build_nginx /buildpack/nginx-heroku-20.tgz

build-heroku-22:
	@echo "Building nginx in Docker for heroku-22..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-22" -w /buildpack heroku/heroku:22-build scripts/build_nginx /buildpack/nginx-heroku-22.tgz

build-heroku-24:
	@echo "Building nginx in Docker for heroku-24..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-24" -w /buildpack heroku/heroku:24-build scripts/build_nginx /buildpack/nginx-heroku-24.tgz

shell:
shell-24:
	@echo "Opening heroku-24 shell..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-24" -e "PORT=5000" -w /buildpack heroku/heroku:24-build bash

shell-22:
	@echo "Opening heroku-22 shell..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-22" -e "PORT=5000" -w /buildpack heroku/heroku:22-build bash

shell-20:
	@echo "Opening heroku-20 shell..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-20" -e "PORT=5000" -w /buildpack heroku/heroku:20-build bash

shell-18:
	@echo "Opening heroku-18 shell..."
	@docker run -v $(shell pwd):/buildpack --rm -it -e "STACK=heroku-18" -e "PORT=5000" -w /buildpack heroku/heroku:18-build bash
