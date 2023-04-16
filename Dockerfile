# Stage 1 - Generate our recipe file for dependencies.
FROM rust as planner
WORKDIR /app
RUN cargo install cargo-chef
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# Stage 2 - Build our dependencies.
FROM rust as cacher
WORKDIR /app
RUN cargo install cargo-chef
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

# Use the official Rust image as our builder.
FROM rust as builder

# Create appUser.
ENV USER=web
ENV UID=1001

RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistant" \
    --shell /sbin/nologin \
    --no-create-home \
    --uid ${UID} \
    ${USER}

# Copy local code to the container image.
COPY . /app

# Set the working directory.
WORKDIR /app

# copy the cached dependencies
COPY --from=cacher /app/target target
COPY --from=cacher /usr/local/cargo /usr/local/cargo

# Build the app.
RUN cargo build --release

# Use Google's distroless as a lean production image.
FROM gcr.io/distroless/cc-debian11

# Import from builder.
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/target/release/actix-template /app/actix-template
WORKDIR /app

USER web:web

# Run the web service on container startup.
CMD ["./actix-template"]