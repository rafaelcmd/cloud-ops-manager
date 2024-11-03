FROM golang:1.20 AS builder

WORKDIR /app

COPY go.mod ./

RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /resource-provisioner-consumer ./cmd

FROM alpine:latest

RUN apk --no-cache add ca-certificates bash && \
    wget https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip && \
    unzip terraform_1.9.8_linux_amd64.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_1.9.8_linux_amd64.zip

COPY --from=builder /resource-provisioner-consumer /usr/local/bin/

RUN chmod +x /usr/local/bin/resource-provisioner-consumer

ENTRYPOINT ["/usr/local/bin/resource-provisioner-consumer"]