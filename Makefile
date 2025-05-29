# Базовий образ з quay.io
FROM quay.io/projectquay/golang:latest AS builder

# Аргументи, що передаються з Makefile або docker build команди
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG APP_VERSION="dev"
ARG APP_NAME="app"
ARG MAIN_GO_FILE="./main.go" # Очікуємо, що main.go є в корені контексту збірки
ARG APP_VERSION_VAR_PATH="main.appVersion"

WORKDIR /app

# Копіюємо файли модулів Go та завантажуємо залежності.
# Ці файли мають бути в контексті збірки (тобто, в каталозі з Dockerfile).
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Копіюємо решту вихідного коду.
COPY . .

# Компіляція програми.
# TARGETOS та TARGETARCH надаються автоматично Docker Buildx.
RUN echo "Building for $TARGETPLATFORM (OS: $TARGETOS, Arch: $TARGETARCH)" && \
    echo "App Version: $APP_VERSION, App Name: $APP_NAME, Main Go File: $MAIN_GO_FILE, Version Var Path: $APP_VERSION_VAR_PATH" && \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -ldflags="-s -w -X '${APP_VERSION_VAR_PATH}=${APP_VERSION}'" \
    -o /app/bin/${APP_NAME} ${MAIN_GO_FILE}

# Фінальний мінімальний образ
FROM scratch

WORKDIR /app

# Копіюємо бінарний файл з етапу збірки
COPY --from=builder /app/bin/${APP_NAME} /app/${APP_NAME}

# Точка входу
ENTRYPOINT ["/app/tgbot"] # Замініть 'tgbot' на фактичне ім'я APP_NAME, якщо воно динамічне для ENTRYPOINT
CMD ["start"]