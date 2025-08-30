# Cloud Ops Manager API Makefile

.PHONY: help build test swagger-gen swagger-install clean run

# Default target
help:
	@echo "Available targets:"
	@echo "  build          - Build the application"
	@echo "  test           - Run tests"
	@echo "  swagger-gen    - Generate OpenAPI documentation from code annotations"
	@echo "  swagger-install- Install swag CLI tool"
	@echo "  run            - Run the application"
	@echo "  clean          - Clean build artifacts"

# Build the application
build:
	go build -o bin/server ./cmd/server

# Run tests
test:
	go test ./...

# Generate OpenAPI documentation from Swagger annotations
swagger-gen:
	swag init -g cmd/server/main.go

# Install swag CLI tool
swagger-install:
	go install github.com/swaggo/swag/cmd/swag@latest

# Run the application
run: build
	./bin/server

# Clean build artifacts
clean:
	rm -rf bin/
	rm -rf docs/docs.go docs/swagger.json docs/swagger.yaml

# Development workflow: regenerate docs and build
dev: swagger-gen build

.DEFAULT_GOAL := help
