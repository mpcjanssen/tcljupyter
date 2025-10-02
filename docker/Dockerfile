#
#
FROM alpine:edge

ENV NOTEBOOKS=/notebooks
ENV CONFIG=/config
ENV PORT=8888
ENV TCLLIBPATH=/libs
ENV VENV=/venv

# Install packages
RUN \
    --mount=type=cache,target=/var/cache/apk \
    apk update &&\
    apk add autoconf bash curl openssh python3 git wget zeromq-dev bsd-compat-headers gcc make python3-dev util-linux-dev musl-dev libffi-dev tar curl-dev fossil &&\
    apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/ nim nimble libtommath-dev

RUN python3 -m venv ${VENV}
RUN \
    --mount=type=cache,target=/root/.cache \
    ${VENV}/bin/pip install jupyterlab jupyterlab-git &&\
    ${VENV}/bin/pip cache purge

# Install tcl9
RUN mkdir /src
WORKDIR /src
RUN wget -q http://prdownloads.sourceforge.net/tcl/tcl9.0.1-src.tar.gz -O - | tar zvx --one-top-level=tcl9 --strip-components 1 &&\
cd tcl9/unix &&\
./configure --prefix=/usr &&\
make && make install

# Install critcl
RUN wget -q  http://github.com/andreas-kupries/critcl/tarball/3.3.1 -O - | tar zvx  --one-top-level=critcl --strip-components 1 &&\
cd ./critcl &&\
ls &&\
tclsh9.0 build.tcl install 

# Install tcllib
RUN wget -q https://core.tcl-lang.org/tcllib/uv/tcllib-2.0.tar.gz -O - | tar zvx --one-top-level=tcllib --strip-components 1 &&\
cd ./tcllib &&\
ls &&\
./configure --prefix=/usr &&\
make && make install 


# Install zmq
RUN wget -q  https://github.com/mpcjanssen/tclzmq/archive/tcl9.tar.gz -O - | tar zvx  --one-top-level=tclzmq --strip-components 1 &&\
cd ./tclzmq &&\
ls &&\
tclsh9.0 build.tcl install /usr/lib 

# Install tcljupyter
RUN git clone -b sqlite https://github.com/mpcjanssen/tcljupyter

## Install tclcurl
#
#RUN fossil clone https://fossil.mpcjanssen.nl/tclcurl --user=root &&\
#cd tclcurl &&\
#touch rebuild2 &&\
#./configure --prefix=/usr &&\
#make && make install

# Install tcl libs
RUN \
    --mount=type=cache,target=/var/cache/apk \
    apk update &&\
    apk add tcl-tls

# Install
RUN mkdir -p /root/.local/share/jupyter/kernels/tcl && echo '{"argv":["tclsh9.0","/src/tcljupyter/init.tcl","{connection_file}"],"display_name":"Tcl 9","language":"tcl","interrupt_mode":"message" }' > /root/.local/share/jupyter/kernels/tcl/kernel.json && mkdir -p ${CONFIG}

# Expose Jupyter port and start Jupyter
EXPOSE ${PORT}
COPY startup.sh /tmp/
RUN mkdir -p ${NOTEBOOKS} ${TCLLIBPATH} && chmod a+x /tmp/startup.sh
CMD ["/tmp/startup.sh"]
