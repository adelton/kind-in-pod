FROM quay.io/podman/stable
RUN dnf install -y kubernetes-client && dnf clean all
RUN curl -Lfso /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-$( rpm --eval '%{_arch}' | sed 's/aarch64/arm64/;t;s/.*/amd64/' )
RUN chmod +x /usr/local/bin/kind
RUN sed -i 's/utsns=.*/utsns="private"/; s/cgroups=.*/cgroups="enabled"/' /etc/containers/containers.conf

# Workaround https://github.com/podman-container-tools/image_build/issues/75
RUN mkdir /etc/containers/containers.conf.d
RUN printf '[containers]\nlog_driver = "k8s-file"\n' > /etc/containers/containers.conf.d/80-workaround-issue-75.conf

COPY kind-cluster.yaml /etc/
COPY kind-create-cluster.sh /usr/local/bin/kind-create-cluster
ENV KIND_EXPERIMENTAL_PROVIDER=podman
ENV KUBECONFIG=/var/lib/containers/kubeconfig
ENTRYPOINT [ "/bin/sh", "-c", "if test \"$0\" != /bin/sh -o \"$#\" -ne 0 ; then exec \"$0\" \"$@\" ; elif test -t 0 ; then exec bash ; else trap : TERM INT; sleep infinity & wait ; fi" ]
