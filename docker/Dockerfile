#
#
FROM debian:testing-slim

ENV JL_DATA /data
ENV JL_CONFIG /config
ENV JL_VENV /venv
ENV JL_PORT 8888

# Install packages
RUN apt-get update && apt-get install -y python3 python3-dev python3-venv python3-pip tcl tcllib tcl-thread tcl-tls tdom build-essential tcl-dev uuid-dev libzmq3-dev git wget tcl tcllib tcl-thread tcl-tls tdom libsqlite3-tcl

# Install jupyterlab
RUN python3 -m venv ${JL_VENV} && ${JL_VENV}/bin/pip install jupyterlab


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

# Install
RUN mkdir -p /root/.local/share/jupyter/kernels/tcl && echo '{"argv":["tclsh8.6","/src/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message" }' > /root/.local/share/jupyter/kernels/tcl/kernel.json && mkdir -p ${JL_DATA} ${JL_CONFIG}

# Expose Jupyter port and start Jupyter
EXPOSE ${JL_PORT}
COPY startup.sh /tmp/
RUN chmod a+x /tmp/startup.sh
CMD /tmp/startup.sh
