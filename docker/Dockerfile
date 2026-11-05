#
#
FROM alpine:latest

ENV UUID=1000
ENV UGID=1000
ENV NOTEBOOKS=/home/tcljupyter/notebooks
ENV CONFIG=/home/tcljupyter/config
ENV PORT=8888
ENV TCLLIBPATH=/home/tcljupyter/tcl/lib
ENV VENV=/venv

RUN addgroup ${UGID}
RUN adduser -D \
    -u ${UUID} \
    -G ${UGID} \
    -h /home/tcljupyter \
    tcljupyter


# Install packages
RUN \
    apk update &&\
    apk add --no-cache autoconf bash curl openssh python3 git wget zeromq-dev bsd-compat-headers gcc make python3-dev util-linux-dev musl-dev libffi-dev tar curl-dev fossil alpine-sdk cmake



# Install tcl9
RUN mkdir /src
WORKDIR /src
RUN wget -q http://prdownloads.sourceforge.net/tcl/tcl9.1.0-src.tar.gz -O - | tar zvx --one-top-level=tcl9 --strip-components 1 &&\
cd tcl9/unix &&\
./configure --prefix=/usr &&\
make && make install

RUN python3 -m venv ${VENV}
RUN \
    --mount=type=cache,target=/root/.cache \
    ${VENV}/bin/pip install jupyterlab jupyterlab-git &&\
    ${VENV}/bin/pip cache purge



# Install tcljupyter
RUN git clone https://github.com/mpcjanssen/tcljupyter &&\
cd tcljupyter &&\
make install-docker

# Expose Jupyter port and start Jupyter
EXPOSE ${PORT}
COPY startup.sh /home/tcljupyter/
RUN mkdir -p ${NOTEBOOKS} ${TCLLIBPATH} && chmod a+x /home/tcljupyter/startup.sh
RUN chown -R ${UUID}:${UGID} /home/tcljupyter
USER tcljupyter
WORKDIR /home/tcljupyter
CMD ["/home/tcljupyter/startup.sh"]
