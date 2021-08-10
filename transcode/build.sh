#Replace registry repo path below with your repo path. It should be in format <region>.ocir.io/<tenancy-name>/<repo-name>
OCIR_REPO="<OCIR repo path>"
docker build -t transcoder:latest . --no-cache
docker tag transcoder:latest ${OCIR_REPO}/transcoder:latest
docker push ${OCIR_REPO}/transcoder:latest
