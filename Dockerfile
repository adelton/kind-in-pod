FROM quay.io/podman/stable
RUN curl -Lso /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
RUN chmod +x /usr/local/bin/kind
RUN sed -i 's/utsns=.*/utsns="private"/; s/cgroups=.*/cgroups="enabled"/' /etc/containers/containers.conf
COPY kind-cluster-rootless.yaml /etc/kind-cluster-rootless.yaml
ENV KIND_EXPERIMENTAL_PROVIDER podman
