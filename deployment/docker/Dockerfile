# Multi-stage Dockerfile for DevGuard AI Copilot
# Satisfies Requirements: 13.4 (Containerized deployment)

# Build stage
FROM ubuntu:22.04 AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
ENV FLUTTER_HOME="/opt/flutter"
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME
RUN flutter doctor -v
RUN flutter config --enable-linux-desktop

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Get dependencies and build
RUN flutter pub get
RUN flutter test
RUN flutter build linux --release

# Runtime stage
FROM ubuntu:22.04 AS runtime

# Install runtime dependencies (removed SQLite, added curl for Supabase connectivity)
RUN apt-get update && apt-get install -y \
    libgtk-3-0 \
    libblkid1 \
    liblzma5 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd -m -s /bin/bash devguard

# Create app directory
RUN mkdir -p /opt/devguard-ai-copilot
WORKDIR /opt/devguard-ai-copilot

# Copy built application
COPY --from=builder /app/build/linux/x64/release/bundle/ .

# Set ownership
RUN chown -R devguard:devguard /opt/devguard-ai-copilot

# Switch to app user
USER devguard

# Expose port (if needed for web interface)
EXPOSE 8080

# Health check with Supabase connectivity verification
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f devguard_ai_copilot && \
        if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then \
            curl -f "$SUPABASE_URL/rest/v1/" -H "apikey: $SUPABASE_ANON_KEY"; \
        else \
            echo "Supabase environment variables not set"; \
        fi || exit 1

# Set entrypoint
ENTRYPOINT ["./devguard_ai_copilot"]

# Labels for metadata
LABEL maintainer="DevGuard Team <team@devguard.ai>"
LABEL version="1.0.0"
LABEL description="DevGuard AI Copilot - AI-powered development security and productivity copilot"
LABEL org.opencontainers.image.title="DevGuard AI Copilot"
LABEL org.opencontainers.image.description="AI-powered development security and productivity copilot"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="DevGuard Team"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/devguard/ai-copilot"