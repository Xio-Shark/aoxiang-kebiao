# 编译阶段
FROM golang:1.21-alpine AS builder

WORKDIR /src

# 安装git（某些依赖需要）
RUN apk add --no-cache git

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 编译
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/parser-service ./cmd/server

# 运行阶段 - 使用distroless镜像
FROM gcr.io/distroless/static:nonroot

WORKDIR /app

# 从builder复制二进制文件
COPY --from=builder /out/parser-service /app/parser-service

# 暴露端口
EXPOSE 8080

# 使用非root用户运行
USER nonroot:nonroot

ENTRYPOINT ["/app/parser-service"]
