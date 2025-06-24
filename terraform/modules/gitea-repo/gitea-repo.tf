# Your existing repo creation resource
resource "null_resource" "create_repo" {
  provisioner "local-exec" {
    command = <<EOT
      curl -X POST ${var.gitea_base_url}/api/v1/user/repos \
        -u ${var.gitea_user}:${var.gitea_password} \
        -H 'Content-Type: application/json' \
        -d '{"name": "${var.repo_name}"}'
    EOT
  }
}

# Create the Go application file
resource "null_resource" "create_main_go" {
  depends_on = [null_resource.create_repo]

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST ${var.gitea_base_url}/api/v1/repos/${var.gitea_user}/${var.repo_name}/contents/main.go \
        -u ${var.gitea_user}:${var.gitea_password} \
        -H 'Content-Type: application/json' \
        -d '{
          "message": "Add Go hello world application",
          "content": "'$(echo 'package main

import "fmt"

func main() {
    fmt.Println("Hello World from Go!")
}' | base64 -w 0)'"
        }'
    EOT
  }
}

# Create the Dockerfile
resource "null_resource" "create_dockerfile" {
  depends_on = [null_resource.create_main_go]

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST ${var.gitea_base_url}/api/v1/repos/${var.gitea_user}/${var.repo_name}/contents/Dockerfile \
        -u ${var.gitea_user}:${var.gitea_password} \
        -H 'Content-Type: application/json' \
        -d '{
          "message": "Add Dockerfile for Go application",
          "content": "'$(echo '# Use the official Go image as build environment
FROM golang:1.21-alpine AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy the Go source code
COPY main.go .

# Build the Go application
RUN go build -o hello-world main.go

# Use a minimal Alpine image for the final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests (if needed)
RUN apk --no-cache add ca-certificates

# Set working directory
WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/hello-world .

# Make the binary executable
RUN chmod +x hello-world

# Command to run the application
CMD ["./hello-world"]' | base64 -w 0)'"
        }'
    EOT
  }
}

# Optional: Create a .gitignore file for Go projects
resource "null_resource" "create_gitignore" {
  depends_on = [null_resource.create_dockerfile]

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST ${var.gitea_base_url}/api/v1/repos/${var.gitea_user}/${var.repo_name}/contents/.gitignore \
        -u ${var.gitea_user}:${var.gitea_password} \
        -H 'Content-Type: application/json' \
        -d '{
          "message": "Add .gitignore for Go project",
          "content": "'$(echo '# Go build artifacts
*.exe
*.exe~
*.dll
*.so
*.dylib
hello-world

# Test binary, built with `go test -c`
*.test

# Output of the go coverage tool
*.out

# Go workspace file
go.work

# IDE files
.vscode/
.idea/' | base64 -w 0)'"
        }'
    EOT
  }
}

# Optional: Create a README.md file
resource "null_resource" "create_readme" {
  depends_on = [null_resource.create_gitignore]

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST ${var.gitea_base_url}/api/v1/repos/${var.gitea_user}/${var.repo_name}/contents/README.md \
        -u ${var.gitea_user}:${var.gitea_password} \
        -H 'Content-Type: application/json' \
        -d '{
          "message": "Add README documentation",
          "content": "'$(echo '# Hello World Go Application

A simple Go application that prints "Hello World from Go!" to the console.

## Building and Running

### Using Go directly:
```bash
go run main.go
```

### Using Docker:
```bash
# Build the Docker image
docker build -t hello-world-go .

# Run the container
docker run hello-world-go
```

## Files

- `main.go` - The main Go application
- `Dockerfile` - Multi-stage Docker build configuration
- `.gitignore` - Git ignore rules for Go projects' | base64 -w 0)'"
        }'
    EOT
  }
}
