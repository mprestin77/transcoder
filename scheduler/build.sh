#Replace registry repo path below with your repo path. It should be in format <region>.ocir.io/<tenancy-name>/<repo-name>
OCIR_REPO="<OCIR repo path>"
docker build -t scheduler:latest . --no-cache
#Replace registry path below with your repo name
docker tag scheduler:latest ${OCIR_REPO}/scheduler:latest
docker push ${OCIR_REPO}/scheduler:latest
