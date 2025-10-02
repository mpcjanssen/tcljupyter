podman build -t mpcjanssen/tcljupyter:$(uname -m) .
podman push mpcjanssen/tcljupyter:$(uname -m) docker://docker.io/mpcjanssen/tcljupyter:$(uname -m)
