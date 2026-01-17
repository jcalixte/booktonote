# Multi-stage Dockerfile for BookToNote OCR Server

# Build stage
FROM hexpm/elixir:1.18.1-erlang-28.0-debian-bookworm-20241202-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Gleam
RUN curl -fsSL https://gleam.run/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Set working directory
WORKDIR /app

# Copy dependency files
COPY gleam.toml manifest.toml ./

# Download dependencies
RUN gleam deps download

# Copy source code
COPY src ./src
COPY test ./test

# Build the application for production
RUN gleam export erlang-shipment

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-eng \
    ca-certificates \
    libssl3 \
    libncurses6 \
    && rm -rf /var/lib/apt/lists/*

# Install Erlang runtime
RUN apt-get update && apt-get install -y \
    wget \
    && wget -O - https://packages.erlang-solutions.com/debian/erlang_solutions.asc | apt-key add - \
    && echo "deb https://packages.erlang-solutions.com/debian bookworm contrib" | tee /etc/apt/sources.list.d/erlang.list \
    && apt-get update && apt-get install -y \
    esl-erlang=1:28.0 \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy built application from builder
COPY --from=builder /app/build/erlang-shipment ./

# Expose port
EXPOSE 8080

# Set environment variables
ENV PORT=8080

# Run the application
CMD ["./entrypoint.sh", "run"]
