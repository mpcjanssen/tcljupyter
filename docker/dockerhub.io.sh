podman manifest create docker.io/mpcjanssen/tcljupyter:latest
podman build --platform linux/amd64,linux/arm64 --manifest docker.io/mpcjanssen/tcljupyter:latest .
podman manifest push docker.io/mpcjanssen/tcljupyter:latest
