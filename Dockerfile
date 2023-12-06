FROM quay.io/podman/stable
RUN dnf install -y kubernetes-client && dnf clean all
RUN curl -Lso /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
RUN chmod +x /usr/local/bin/kind
RUN sed -i 's/utsns=.*/utsns="private"/; s/cgroups=.*/cgroups="enabled"/' /etc/containers/containers.conf
COPY kind-cluster.yaml kind-cluster-rootless.yaml /etc/
ENV KIND_EXPERIMENTAL_PROVIDER podman
ENV KUBECONFIG /var/lib/containers/kubeconfig
ENTRYPOINT trap : TERM INT; sleep infinity & wait
