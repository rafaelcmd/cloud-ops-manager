# Internal Developer Platform Scaffolder Makefile
#
# The scaffolder runs as a container on EKS like the other two services
# (ADR-0004). Nothing here needs the AWS SAM CLI or the Amazon.Lambda.Tools
# global tool; local runs go through docker compose against LocalStack.

# The compose targets drive the ROOT compose file, not the fragment in this
# directory: the fragment's otel-collector dependency is defined there, and the
# root file is what `include:`s this one. Running the fragment alone fails with
# "undefined service otel-collector".
COMPOSE := docker compose -f ../../docker-compose.dev.yaml

# Which worker's queue `seed` puts the fixture on. Override for the other one:
#   make seed W=github E=events/create-repository.json
W ?= state
QUEUE_URL = http://localhost:4566/000000000000/internal-developer-platform-scaffolder-$(W)-tasks-local

.PHONY: help restore build test test-unit test-integration coverage format format-check \
        image up down logs seed clean

help:
	@echo "Available targets:"
	@echo "  restore          - Restore NuGet packages"
	@echo "  build            - Build the solution"
	@echo "  test             - Run unit tests (no AWS, no Docker)"
	@echo "  test-integration - Run adapter tests against LocalStack and the sandbox org"
	@echo "  coverage         - Run unit tests with coverage collection"
	@echo "  format           - Apply formatting fixes"
	@echo "  format-check     - Verify formatting without changing files"
	@echo "  image            - Build the container image"
	@echo "  up               - Start the worker and LocalStack"
	@echo "  down             - Stop them and drop the volumes"
	@echo "  logs             - Follow the worker's logs"
	@echo "  seed             - Enqueue a task fixture (E=events/reserve-name.json W=state)"
	@echo "  clean            - Remove build artifacts"

restore:
	dotnet restore

build:
	dotnet build

# Unit tests only: domain, application and dispatcher wiring
test: test-unit

test-unit:
	dotnet test tests/Scaffolder.UnitTests

# Adapter tests. Opt-in because they need Docker and credentials.
test-integration:
	SCAFFOLDER_INTEGRATION=1 dotnet test tests/Scaffolder.IntegrationTests

# Coverage, in the shape the CI job publishes to the step summary
coverage:
	dotnet test tests/Scaffolder.UnitTests --collect:"XPlat Code Coverage"

format:
	dotnet format

format-check:
	dotnet format --verify-no-changes

# Container
image:
	docker build -f Dockerfile.dev -t internal-developer-platform-scaffolder:dev .

up:
	$(COMPOSE) up --build -d scaffolder

down:
	$(COMPOSE) down -v

logs:
	$(COMPOSE) logs -f scaffolder

# Put one task on the local queue. See events/README.md for what the fake task
# token does and does not exercise.
E ?= events/reserve-name.json

seed:
	aws --endpoint-url http://localhost:4566 --region us-east-1 sqs send-message \
	  --queue-url "$(QUEUE_URL)" \
	  --message-body "file://$(E)"

clean:
	dotnet clean
	find . -type d \( -name bin -o -name obj \) -prune -exec rm -rf {} +

.DEFAULT_GOAL := help
