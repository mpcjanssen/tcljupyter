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
    apk add bash curl python3 git wget zeromq-dev gcc make python3-dev util-linux-dev musl-dev libffi-dev tar curl-dev fossil &&\
    apk add nim nimble

RUN python3 -m venv ${VENV}
RUN \
    --mount=type=cache,target=/root/.cache \
    ${VENV}/bin/pip install jupyterlab &&\
    ${VENV}/bin/pip cache purge

RUN \
    --mount=type=cache,target=/var/cache/apk \
    apk update &&\
    apk add tcl-dev tcl-tls tcl-lib

# Install tcljupyter
RUN mkdir /src
WORKDIR /src
RUN git clone https://github.com/mpcjanssen/tcljupyter .

# Install rl_json
RUN wget -q https://github.com/mpcjanssen/rl_json/archive/binder.tar.gz -O - | tar zvx --one-top-level=rl_json --strip-components 1 &&\
cd ./rl_json &&\
./configure --prefix=/usr &&\
make && make install


# Install tcllib
RUN wget -q https://github.com/mpcjanssen/tcllib/archive/tcllib-1-20.tar.gz -O - | tar zvx --one-top-level=tcllib --strip-components 1 &&\
cd ./tcllib &&\
 ls &&\
 ./configure --prefix=/usr &&\
 make && make install 

# Install critcl
RUN wget -q https://github.com/mpcjanssen/critcl/archive/3.1.18.1.tar.gz -O - | tar zvx  --one-top-level=critcl --strip-components 1 &&\
cd ./critcl &&\
ls &&\
tclsh build.tcl install 

# Install zmq
RUN wget -q  https://github.com/mpcjanssen/tclzmq/archive/binder.tar.gz -O - | tar zvx  --one-top-level=tclzmq --strip-components 1 &&\
cd ./tclzmq &&\
ls &&\
tclsh build.tcl install 

# Install tclcurl

RUN fossil clone https://fossil.mpcjanssen.nl/tclcurl --user=root &&\
cd tclcurl &&\
touch rebuild2 &&\
./configure --prefix=/usr &&\
make && make install

# Install
RUN mkdir -p /root/.local/share/jupyter/kernels/tcl && echo '{"argv":["tclsh8.6","/src/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message" }' > /root/.local/share/jupyter/kernels/tcl/kernel.json && mkdir -p ${CONFIG}

# Expose Jupyter port and start Jupyter
EXPOSE ${PORT}
COPY startup.sh /tmp/
RUN mkdir -p ${NOTEBOOKS} ${TCLLIBPATH} && chmod a+x /tmp/startup.sh
CMD /tmp/startup.sh
