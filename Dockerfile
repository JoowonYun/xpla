#
# xpla localnet
#
# build:
#   docker build --force-rm -t xpladev/xpla .
# run:
#   docker run --rm -it --env-file=path/to/.env --name xpla-localnet xpladev/xpla

### BUILD
FROM golang:1.19-alpine AS build
WORKDIR /localnet

# Create appuser.
RUN adduser -D -g '' valiuser
# Install required binaries
RUN apk add --update --no-cache zip git make cmake build-base linux-headers musl-dev libc-dev

# Copy source files
COPY . /localnet/

ENV LIBWASMVM_VERSION=v1.3.1

RUN git clone --depth 1 https://github.com/microsoft/mimalloc; cd mimalloc; mkdir build; cd build; cmake ..; make -j$(nproc); make install
ENV MIMALLOC_RESERVE_HUGE_OS_PAGES=4

# See https://github.com/CosmWasm/wasmvm/releases
ADD https://github.com/CosmWasm/wasmvm/releases/download/${LIBWASMVM_VERSION}/libwasmvm_muslc.aarch64.a /lib/libwasmvm_muslc.aarch64.a
ADD https://github.com/CosmWasm/wasmvm/releases/download/${LIBWASMVM_VERSION}/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.x86_64.a
RUN sha256sum /lib/libwasmvm_muslc.aarch64.a | grep 9f5f387bddbd51a549f2d8eb2cc0f08030f311610c43004b96c141a733b681bc
RUN sha256sum /lib/libwasmvm_muslc.x86_64.a | grep 129da0e50eaa3da093eb84c3a8f48da20b9573f3afdf83159b3984208c8ec5c3

# Copy the library you want to the final location that will be found by the linker flag `-lwasmvm_muslc`
RUN cp /lib/libwasmvm_muslc.`uname -m`.a /lib/libwasmvm_muslc.a

# Build executable
RUN LEDGER_ENABLED=false BUILD_TAGS=muslc LDFLAGS='-linkmode=external -extldflags "-L/localnet/mimalloc/build -lmimalloc -Wl,-z,muldefs -static"' make build

# --------------------------------------------------------
FROM alpine:3.15 AS runtime

WORKDIR /opt
RUN [ "mkdir", "-p", "/opt/tests/integration" ]

COPY --from=build /localnet/build/xplad /usr/bin/xplad
COPY --from=build /localnet/tests/e2e /opt/tests/e2e

# Expose Cosmos ports
EXPOSE 9090
EXPOSE 8545
EXPOSE 26656
#EXPOSE 26657

# Set entry point
CMD [ "/usr/bin/xplad", "version" ]
