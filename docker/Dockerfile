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
    apk add nim nimble bsd-compat-headers

RUN python3 -m venv ${VENV}
RUN \
    --mount=type=cache,target=/root/.cache \
    ${VENV}/bin/pip install jupyterlab &&\
    ${VENV}/bin/pip cache purge


# Install tcl8
RUN apk add minizip
RUN mkdir /tcl9
COPY tcl9.0b3-src.tar.gz /tcl9
WORKDIR /tcl9
RUN tar xvf tcl9.0b3-src.tar.gz
RUN cd tcl9.0b3/unix &&\
./configure --prefix=/usr --disable-zipfs &&\
make install


# Install tcljupyter
RUN mkdir /src
WORKDIR /src
RUN git clone https://github.com/mpcjanssen/tcljupyter .

# # Install rl_json
# RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing \
#   libtommath-dev
# RUN wget -q https://github.com/mpcjanssen/rl_json/archive/binder.tar.gz -O - | tar zvx --one-top-level=rl_json --strip-components 1 &&\
# cd ./rl_json &&\
# ./configure --prefix=/usr &&\
# make && make install


# Install tcllib
COPY tcllib-1.21-9.tar.gz .
RUN tar zvxf tcllib-1.21-9.tar.gz --one-top-level=tcllib --strip-components 1 &&\
cd ./tcllib &&\
 ls &&\
 ./configure --prefix=/usr &&\
 make install 

# Install critcl
COPY critcl-3.2.tar.gz .
RUN tar zvxf critcl-3.2.tar.gz  --one-top-level=critcl --strip-components 1 &&\
cd ./critcl &&\
ls &&\
tclsh9.0 build.tcl install 

# Install zmq
COPY tclzmq.tar.gz .
RUN tar zvxf tclzmq.tar.gz  --one-top-level=tclzmq --strip-components 1 &&\
cd ./tclzmq &&\
ls &&\
tclsh9.0 build.tcl install 

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
