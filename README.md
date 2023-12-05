
# Kind in pod

The [Kind project](https://kind.sigs.k8s.io/) project provides a tool
to start a Kubernetes cluster running within containers in
[Docker](https://www.docker.com/) / [Moby engine](https://mobyproject.org/)
or [podman](https://podman.io/).

When a Kubernetes cluster is needed for testing, it is then quite natural
to want to run in a containerized manner itself, either locally or
for example in Kubernetes or OpenShift cluster, to test
[Open Cluster Management](https://open-cluster-management.io/),
[Advanced Cluster Management](https://www.redhat.com/en/technologies/management/advanced-cluster-management),
or to just test behaviour of applications across clusters.

## Initial interactive investigation

The environment for the setup were done on Fedora 39 with podman 4.8.0,
to match the OS and podman version that the `quay.io/podman/stable`
image was based on as of 2023-12-05.

We start our investigatory path with a rootless podman container
with podman installed in it, to which we install **kind**:

```
$ podman run --rm -ti --privileged -h container quay.io/podman/stable
[root@container /]# curl -Lso /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
[root@container /]# chmod +x /usr/local/bin/kind
[root@container /]# kind create cluster --retain
enabling experimental podman provider
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼 
 ✗ Preparing nodes 📦  
ERROR: failed to create cluster: command "podman run --name kind-control-plane --hostname kind-control-plane --label io.x-k8s.kind.role=control-plane --privileged --tmpfs /tmp --tmpfs /run --volume 56008094e84febb152be2aebec4d96680907960865199e893ceca31755eaa407:/var:suid,exec,dev --volume /lib/modules:/lib/modules:ro -e KIND_EXPERIMENTAL_CONTAINERD_SNAPSHOTTER --detach --tty --net kind --label io.x-k8s.kind.cluster=kind -e container=podman --cgroupns=private --publish=127.0.0.1:39725:6443/tcp -e KUBECONFIG=/etc/kubernetes/admin.conf docker.io/kindest/node@sha256:3966ac761ae0136263ffdb6cfd4db23ef8a83cba8a463690e98317add2c9ba72" failed with error: exit status 125
Command Output: Error: invalid config provided: cannot set hostname when running in the host UTS namespace: invalid configuration
```

The first error can be resolved by
```
[root@container /]# sed -i 's/utsns=.*/utsns="private"/' /etc/containers/containers.conf
```

which gets us to
```
 ✗ Preparing nodes 📦  
ERROR: failed to create cluster: could not find a log line that matches "Reached target .*Multi-User System.*|detected cgroup v1"
```

Since we used the `--retain` argument, the `kind-control-plane`
container created by **kind** stayed around and we can check what it
reported:
```
[root@container /]# podman logs kind-control-plane
INFO: running in a user namespace (experimental)
ERROR: UserNS: cpu controller needs to be delegated
```

The solution is to add `; s/cgroups=.*/cgroups="enabled"/` to the `sed`
command used to tweak `/etc/containers/containers.conf`. This change
gets us to
```
[root@container /]# kind create cluster --retain
enabling experimental podman provider
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✗ Starting control-plane 🕹️ 
ERROR: failed to create cluster: failed to init node with kubeadm: command "podman exec --privileged kind-control-plane kubeadm init --skip-phases=preflight --config=/kind/kubeadm.conf --skip-token-print --v=6" failed with error: exit status 1
Command Output: I1205 16:36:20.931114     134 initconfiguration.go:255] loading configuration from "/kind/kubeadm.conf"
W1205 16:36:20.932066     134 initconfiguration.go:332] [config] WARNING: Ignored YAML document with GroupVersionKind kubeadm.k8s.io/v1beta3, Kind=JoinConfiguration
[...]
[kubelet-check] It seems like the kubelet isn't running or healthy.
[kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10248/healthz' failed with error: Get "http://localhost:10248/healthz": dial tcp [::1]:10248: connect: connection refused.
```

The `podman logs kind-control-plane` now has just systemd startup
messages but we can continue the debugging with
```
[root@container /]# podman exec kind-control-plane journalctl -l
```
where
```
Dec 05 16:50:08 kind-control-plane kubelet[172]: E1205 16:50:08.902786     172 container_manager_linux.go:440] "Updating kernel flag failed (Hint: enable KubeletInUserNamespace feature flag to ignore the error)" err="open /proc/sys/kernel/panic: permission denied" flag="kernel/panic"
```
seems the most relevant.

With a `kind-cluster.yaml` file
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        feature-gates: KubeletInUserNamespace=true
```
we can actually get the initial step pass:
```
[root@container /]# kind create cluster --retain --config kind-cluster.yaml
enabling experimental podman provider
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a nice day! 👋
```

We can then use
```
[root@container /]# podman exec kind-control-plane kubectl get all -A
```
to check what's in the Kubernetes-in-podman-in-podman cluster by
default.
