# ============================================================
# Stage 1: Build the friday binary
# ============================================================
FROM golang:1.25.7-alpine AS builder

RUN apk add --no-cache git make

WORKDIR /src

# Cache dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN make build

# ============================================================
# Stage 2: Minimal runtime image
# ============================================================
FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata

# Copy binary (dynamically named based on platform)
COPY --from=builder /src/build/friday* /usr/local/bin/
RUN ln -s /usr/local/bin/friday-* /usr/local/bin/friday 2>/dev/null || true

# Copy builtin skills
COPY --from=builder /src/skills /opt/friday/skills

# Create friday home directory
RUN mkdir -p /root/.friday/workspace/skills && \
    cp -r /opt/friday/skills/* /root/.friday/workspace/skills/ 2>/dev/null || true

ENTRYPOINT ["friday"]
CMD ["gateway"]
