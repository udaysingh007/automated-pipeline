# Use the official Go image as build stage
FROM golang:1.21-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go mod files (if you have them, otherwise skip this step)
# COPY go.mod go.sum ./
# RUN go mod download

# Copy source code
COPY main.go .

# Build the application
RUN go build -o main main.go

# Use a minimal base image for the final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests (if needed)
RUN apk --no-cache add ca-certificates

# Set working directory
WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/main .

# Expose port 8080
EXPOSE 8080

# Run the application
CMD ["./main"]