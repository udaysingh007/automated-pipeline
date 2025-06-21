FROM golang:1.21 as builder

WORKDIR /app
COPY main.go .
RUN go build -o app .

FROM alpine
COPY --from=builder /app/app /app
ENTRYPOINT ["/app"]

