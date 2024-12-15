FROM golang:1.20 AS builder

WORKDIR /app

COPY go.mod ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /api ./cmd/server

FROM alpine:latest

RUN apk --no-cache add ca-certificates bash

COPY --from=builder /api /usr/local/bin/

RUN chmod +x /usr/local/bin/api

ENTRYPOINT ["/usr/local/bin/api"]