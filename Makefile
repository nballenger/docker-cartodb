.PHONY: build help ssl configure install run shell stop clean
.DEFAULT_GOAL := help

buildconf?=DEFAULT
repo?=osscarto-single:$(buildconf)

help:
	@echo ""
	@echo "Usage: make [COMMAND] ([buildconf=<NAME>]|repo=<NAME>)"
	@echo ""
	@echo "  Commands"
	@echo "            generate-ssl  - generates SSL certs for local use"
	@echo "            configure     - generates conf files and scripts"
	@echo "            build         - executes build script as configured"
	@echo "            run           - starts a container from the built image"
	@echo "            shell         - enters a bash shell on the container"
	@echo "            stop          - stops the running container"
	@echo "            clean         - removes all generated files"
	@echo "            install       - runs generate-ssl, configure, build"
	@echo ""
	@echo "  With no buildconf or repo arguments, uses the DEFAULT build conf."
	@echo ""
	@echo "  Standard usage is to run 'make install' the first time you use the"
	@echo "  repository, to generate the SSL certs, config files, and scripts."
	@echo "  Then, perform the following manual steps"
	@echo ""
	@echo "     1) Add your preferred hostname to your /etc/hosts file. By default"
	@echo "        this will be 'osscarto-single.localhost'."
	@echo "     2) Add the file docker/ssl/osscarto-singleCA.pem file to your"
	@echo "        local trusted certificate store."
	@echo ""
	@echo "  Once you've done that, you can use 'make run', 'make shell', and"
	@echo "  'make stop' to interact with the built container."
	@echo ""

build:
	@echo "Building the Docker image"
	bin/generated/docker-build-command.sh -t $(repo)

generate-ssl:
	@printf "\nGenerating SSL certificates into docker/ssl\n\n"
	bin/generate-ssl-certs.sh -i

configure:
	@echo "Generating config and build script using values from build config $(buildconf)..."
	bin/configure-repo.sh -c $(buildconf)

install: generate-ssl configure build

run:
	bin/generated/docker-run-command.sh -t $(repo)

shell:
	bin/generated/docker-exec-shell.sh -t $(repo)

stop:
	bin/generated/docker-stop-command.sh -t $(repo)

clean:
	rm bin/generated/*.sh
	rm docker/config/*.js docker/config/*.conf docker/config/*.yml docker/config/*.vcl
	rm docker/ssl/*.crt docker/ssl/*.key docker/ssl/*.pem docker/ssl/*.srl docker/ssl/*.csr
