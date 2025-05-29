GIT_TAG_VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null)
GIT_COMMIT_HASH := $(shell git rev-parse --short HEAD)
VERSION         := $(if $(GIT_TAG_VERSION),$(GIT_TAG_VERSION)-$(GIT_COMMIT_HASH),$(GIT_COMMIT_HASH))
ifeq ($(VERSION),)
    VERSION := latest
endif

MODULE_NAME     := tgbot
APP_NAME        := tgbot
MAIN_GO_FILE    := ./main.go

APP_VERSION_VAR_PATH := main.appVersion
LDFLAGS         := -s -w -X '${APP_VERSION_VAR_PATH}=${VERSION}'

# Використовуємо Docker Hub. Замініть YOUR_DOCKERHUB_USERNAME на ваш логін в Docker Hub.
# Якщо у вас немає організації, це буде просто ваш логін.
REGISTRY        := YOUR_DOCKERHUB_USERNAME
IMAGE_NAME_BASE := $(REGISTRY)/$(APP_NAME)

# Визначення HOST_OS та HOST_ARCH з фолбеком
_GO_EXEC_PATH := $(shell command -v go)
ifeq ($(_GO_EXEC_PATH),)
    _DEFAULT_HOST_OS := linux
    _DEFAULT_HOST_ARCH := amd64
    $(warning "Go command not found. Defaulting HOST_OS to '$(_DEFAULT_HOST_OS)' and HOST_ARCH to '$(_DEFAULT_HOST_ARCH)' for 'make image', 'make build' and related tags.")
    HOST_OS := $(_DEFAULT_HOST_OS)
    HOST_ARCH := $(_DEFAULT_HOST_ARCH)
    GO_CMD := echo "Go command not found, using fallback for go operations:"
else
    _TEMP_HOST_OS := $(shell $(_GO_EXEC_PATH) env GOOS)
    _TEMP_HOST_ARCH := $(shell $(_GO_EXEC_PATH) env GOARCH)
    GO_CMD := $(_GO_EXEC_PATH)

    ifeq ($(_TEMP_HOST_OS),)
        HOST_OS := linux
        $(warning "'$(_GO_EXEC_PATH) env GOOS' returned empty. Defaulting HOST_OS to '$(HOST_OS)'.")
    else
        HOST_OS := $(_TEMP_HOST_OS)
    endif

    ifeq ($(_TEMP_HOST_ARCH),)
        HOST_ARCH := amd64
        $(warning "'$(_GO_EXEC_PATH) env GOARCH' returned empty. Defaulting HOST_ARCH to '$(HOST_ARCH)'.")
    else
        HOST_ARCH := $(_TEMP_HOST_ARCH)
    endif
endif

LOCAL_IMAGE_TAG := $(IMAGE_NAME_BASE):$(VERSION)-$(HOST_OS)-$(HOST_ARCH)

$(shell mkdir -p ./bin)

.PHONY: all build clean image push \
        linux arm macos windows \
        build-linux-amd64 build-linux-arm64 \
        build-darwin-amd64 build-darwin-arm64 \
        build-windows-amd64 build-windows-arm64 \
        format lint test get build-all-binaries \
        build-push-multiarch-image

all: build

linux: build-linux-amd64

arm: build-linux-arm64

macos: build-darwin-arm64

windows: build-windows-amd64

build-linux-amd64:
	@mkdir -p bin
	@echo ">>> Building $(APP_NAME) for linux/amd64..."
	@GOOS=linux GOARCH=amd64 CGO_ENABLED=0 $(GO_CMD) build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-linux-amd64 $(MAIN_GO_FILE)
	@echo "Binary: bin/$(APP_NAME)-linux-amd64"

build-linux-arm64:
	@mkdir -p bin
	@echo ">>> Building $(APP_NAME) for linux/arm64..."
	@GOOS=linux GOARCH=arm64 CGO_ENABLED=0 $(GO_CMD) build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-linux-arm64 $(MAIN_GO_FILE)
	@echo "Binary: bin/$(APP_NAME)-linux-arm64"

build-darwin-amd64:
	@mkdir -p bin
	@echo ">>> Building $(APP_NAME) for darwin/amd64 (macOS Intel)..."
	@GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 $(GO_CMD) build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-darwin-amd64 $(MAIN_GO_FILE)
	@echo "Binary: bin/$(APP_NAME)-darwin-amd64"

build-darwin-arm64:
	@mkdir -p bin
	@echo ">>> Building $(APP_NAME) for darwin/arm64 (macOS Apple Silicon)..."
	@GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 $(GO_CMD) build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-darwin-arm64 $(MAIN_GO_FILE)
	@echo "Binary: bin/$(APP_NAME)-darwin-arm64"

build-windows-amd64:
	@mkdir -p bin
	@echo ">>> Building $(APP_NAME) for windows/amd64..."
	@GOOS=windows GOARCH=amd64 CGO_ENABLED=0 $(GO_CMD) build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-windows-amd64.exe $(MAIN_GO_FILE)
	@echo "Binary: bin/$(APP_NAME)-windows-amd64.exe"

build-windows-arm64:
	@mkdir -p bin
	@echo ">>> Building $(APP_NAME) for windows/arm64..."
	@GOOS=windows GOARCH=arm64 CGO_ENABLED=0 $(GO_CMD) build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)-windows-arm64.exe $(MAIN_GO_FILE)
	@echo "Binary: bin/$(APP_NAME)-windows-arm64.exe"

build:
	@mkdir -p bin
	@echo ">>> Building $(APP_NAME) for current host ($(HOST_OS)/$(HOST_ARCH))..."
	@CGO_ENABLED=0 GOOS=$(HOST_OS) GOARCH=$(HOST_ARCH) $(GO_CMD) build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME)$(if $(filter windows,$(HOST_OS)),.exe) $(MAIN_GO_FILE)
	@echo "Binary: bin/$(APP_NAME)$(if $(filter windows,$(HOST_OS)),.exe)"

image:
	@echo ">>> Building Docker image for host platform $(HOST_OS)/$(HOST_ARCH)..."
	@echo "Image tag: $(LOCAL_IMAGE_TAG)"
	@docker buildx build --platform $(HOST_OS)/$(HOST_ARCH) \
		--build-arg APP_VERSION=$(VERSION) \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg MAIN_GO_FILE=$(MAIN_GO_FILE) \
		--build-arg APP_VERSION_VAR_PATH=$(APP_VERSION_VAR_PATH) \
		-t $(LOCAL_IMAGE_TAG) --load .
	@echo ">>> Docker image built and loaded: $(LOCAL_IMAGE_TAG)"

clean:
	@echo ">>> Cleaning up binaries and local Docker image..."
	@rm -rf ./bin
	@$(GO_CMD) clean || echo "'go clean' failed or Go command not available."
	@echo ">>> Attempting to remove Docker image $(LOCAL_IMAGE_TAG)..."
	-@docker rmi $(LOCAL_IMAGE_TAG) 2>/dev/null || echo "Image $(LOCAL_IMAGE_TAG) not found or could not be removed."

format:
	@echo ">>> Formatting Go files..."
	@$(GO_CMD) fmt -s -w $$(find . -type f -name '*.go' -not -path "./vendor/*")

lint:
	@echo ">>> Linting Go files..."
	@golangci-lint run

test:
	@echo ">>> Running Go tests..."
	@$(GO_CMD) test -v ./...

get:
	@echo ">>> Getting/updating Go dependencies..."
	@$(GO_CMD) get -d ./...

build-all-binaries: build-linux-amd64 build-linux-arm64 build-darwin-amd64 build-darwin-arm64 build-windows-amd64 build-windows-arm64

MULTIARCH_PLATFORMS := linux/amd64,linux/arm64
MULTIARCH_IMAGE_TAG := $(IMAGE_NAME_BASE):$(VERSION)-multiarch

build-push-multiarch-image:
	@echo ">>> Building and pushing multi-arch Docker image for platforms: $(MULTIARCH_PLATFORMS)..."
	@echo "Image tag: $(MULTIARCH_IMAGE_TAG)"
	@docker buildx build --platform $(MULTIARCH_PLATFORMS) \
		--build-arg APP_VERSION=$(VERSION) \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg MAIN_GO_FILE=$(MAIN_GO_FILE) \
		--build-arg APP_VERSION_VAR_PATH=$(APP_VERSION_VAR_PATH) \
		-t $(MULTIARCH_IMAGE_TAG) --push .
	@echo ">>> Multi-arch Docker image pushed: $(MULTIARCH_IMAGE_TAG)"

push:
	@echo ">>> Pushing Docker image $(LOCAL_IMAGE_TAG) to $(REGISTRY)..."
	@docker push $(LOCAL_IMAGE_TAG)