#!/bin/sh

apk add curl

arch=$(uname -m)

case $arch in
    "x86_64")
        echo "Running on x86_64 architecture."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" >> /tmp/kubectl
        ;;
    "armv7l")
        echo "Running on ARMv7 architecture."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" >> /tmp/kubectl
        ;;
    "aarch64")
        echo "Running on AArch64 architecture."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl" >> /tmp/kubectl
        ;;
    *)
        echo "Unsupported architecture: $arch"
        ;;
esac

export APISERVER=${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT_HTTPS}
export SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
export NAMESPACE=$(cat ${SERVICEACCOUNT}/namespace)
export TOKEN=$(cat ${SERVICEACCOUNT}/token)
export CACERT=${SERVICEACCOUNT}/ca.crt

alias k='/tmp/kubectl --token=$TOKEN --server=https://$APISERVER --insecure-skip-tls-verify=true'