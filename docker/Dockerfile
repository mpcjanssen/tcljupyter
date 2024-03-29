#
#
FROM debian:latest

ENV JL_DATA /data
ENV JL_CONFIG /config
ENV JL_VENV /venv
ENV JL_PORT 8888

# Install Python
RUN apt-get update 
RUN apt-get install -y python3 python3-dev python3-venv python3-pip


# Install jupyterlab
RUN python3 -m venv ${JL_VENV}
RUN ${JL_VENV}/bin/pip install jupyterlab


# Install Tcl & Tcllib
RUN apt-get update
RUN apt-get install -y tcl tcllib tcl-thread tcl-tls tdom 


# Install tcljupyter
RUN apt-get update
RUN apt-get install -y build-essential tcl-dev uuid-dev libzmq3-dev git wget
RUN mkdir /src
WORKDIR /src
RUN git clone https://github.com/mpcjanssen/tcljupyter .

# Install rl_json
RUN wget -q https://github.com/mpcjanssen/rl_json/archive/binder.tar.gz -O rl_json.tar.gz
RUN tar xf rl_json.tar.gz --one-top-level=rl_json --strip-components 1
WORKDIR ./rl_json
RUN ./configure --prefix=/usr
RUN make && make install
WORKDIR ..

# Install tcllib
RUN wget -q https://github.com/mpcjanssen/tcllib/archive/tcllib-1-20.tar.gz -O tcllib.tar.gz 
RUN tar xf tcllib.tar.gz --one-top-level=tcllib --strip-components 1
WORKDIR ./tcllib
RUN ls
RUN ./configure --prefix=/usr
RUN make && make install
WORKDIR ..

# Install critcl
RUN wget -q https://github.com/mpcjanssen/critcl/archive/3.1.18.1.tar.gz -O critcl.tar.gz
RUN tar xf critcl.tar.gz --one-top-level=critcl --strip-components 1
WORKDIR ./critcl
RUN ls
RUN tclsh build.tcl install
WORKDIR ..

# Install zmq
RUN wget -q  https://github.com/mpcjanssen/tclzmq/archive/binder.tar.gz -O tclzmq.tar.gz
RUN tar xf tclzmq.tar.gz --one-top-level=tclzmq --strip-components 1
WORKDIR ./tclzmq
RUN ls
RUN tclsh build.tcl install 
WORKDIR ..


# Test
RUN ${JL_VENV}/bin/jupyter --paths
RUN tclsh init.tcl


# Install
RUN mkdir -p /root/.local/share/jupyter/kernels/tcl
RUN echo '{"argv":["tclsh8.6","/src/init.tcl","{connection_file}"],"display_name":"Tcl","language":"tcl","interrupt_mode":"message" }' > /root/.local/share/jupyter/kernels/tcl/kernel.json

# Create the Jupyter configuration file
RUN mkdir -p ${JL_DATA}
RUN mkdir -p ${JL_CONFIG}

# Expose Jupyter port and start Jupyter
EXPOSE ${JL_PORT}
COPY startup.sh /tmp/
RUN chmod a+x /tmp/startup.sh
CMD /tmp/startup.sh
