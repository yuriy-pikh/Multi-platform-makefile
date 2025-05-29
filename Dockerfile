FROM quay.io/projectquay/golang:latest AS builder

ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG APP_VERSION="dev"
ARG APP_NAME="tgbot"
ARG MAIN_GO_FILE="./main.go"
ARG APP_VERSION_VAR_PATH="main.appVersion"

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download && go mod verify

COPY . .

RUN echo "Building for $TARGETPLATFORM (OS: $TARGETOS, Arch: $TARGETARCH)" && \
    echo "App Version: $APP_VERSION, App Name: $APP_NAME, Main Go File: $MAIN_GO_FILE, Version Var Path: $APP_VERSION_VAR_PATH" && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -ldflags="-s -w -X ${APP_VERSION_VAR_PATH}=${APP_VERSION}" \
    -o /app/bin/${APP_NAME} ${MAIN_GO_FILE}

FROM scratch

WORKDIR /app

COPY --from=builder /app/bin/${APP_NAME} /app/${APP_NAME}

ENTRYPOINT ["/app/tgbot"]
CMD ["start"]
