set -x
OCIR_USERNAME="<OCIR username - for IDSC users use format ocisateam/oracleidentitycloudservice/<username>"
DOCKER_SERVER="<example - for IAD enter iad.ocir.io>"
DOCKER_EMAIL="<enter your email address>"
echo -n "PASSWORD: "; read -s AUTH_TOKEN  #Use authentication token that you created for OCIR

kubectl -n transcode create secret docker-registry ocirsecret --docker-server='${DOCKER_SERVER}' --docker-username='${OCIR_USERNAME}' --docker-password='${AUTH_TOKEN}' --docker-email='${DOCKER_EMAIL}'

