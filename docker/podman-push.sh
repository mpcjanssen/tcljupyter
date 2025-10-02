podman manifest rm docker.io/mpcjanssen/tcljupyter:latest
podman manifest create docker.io/mpcjanssen/tcljupyter:latest
podman manifest add docker.io/mpcjanssen/tcljupyter:latest docker.io/mpcjanssen/tcljupyter:amd64
podman manifest add docker.io/mpcjanssen/tcljupyter:latest docker.io/mpcjanssen/tcljupyter:arm64
podman manifest push --all docker.io/mpcjanssen/tcljupyter:latest
