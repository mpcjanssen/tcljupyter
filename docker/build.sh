docker build -t mpcjanssen/tcljupyter:$(uname -m) .
docker push mpcjanssen/tcljupyter:$(uname -m) 
