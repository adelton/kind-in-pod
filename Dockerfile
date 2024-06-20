FROM quay.io/podman/stable
RUN dnf install -y kubernetes-client && dnf clean all
RUN curl -Lso /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
RUN chmod +x /usr/local/bin/kind
RUN sed -i 's/utsns=.*/utsns="private"/; s/cgroups=.*/cgroups="enabled"/' /etc/containers/containers.conf
COPY kind-cluster.yaml kind-cluster-rootless.yaml /etc/
COPY kind-create-cluster.sh /usr/local/bin/kind-create-cluster
ENV KIND_EXPERIMENTAL_PROVIDER podman
ENV KUBECONFIG /var/lib/containers/kubeconfig
ENTRYPOINT if test "$0" != /bin/sh -o "$#" -ne 0 ; then exec "$0" "$@" ; elif test -t 0 ; then exec bash ; else trap : TERM INT; sleep infinity & wait ; fi
