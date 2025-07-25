
# Kind in pod

The [Kind project](https://kind.sigs.k8s.io/) project provides a tool
to start a Kubernetes cluster running within containers in
[Docker](https://www.docker.com/) / [Moby engine](https://mobyproject.org/)
or [podman](https://podman.io/).

When a Kubernetes cluster is needed for testing, it is then quite natural
to want to run in a containerized manner itself, either locally or
for example in a Kubernetes cluster, to test
[Open Cluster Management](https://open-cluster-management.io/),
[Advanced Cluster Management](https://www.redhat.com/en/technologies/management/advanced-cluster-management),
or to just test behaviour of applications across clusters.

## Initial interactive investigation

We start our investigatory path with a rootless podman container
with podman installed in it, to which we install **kind**:

```
$ podman run --rm -ti --privileged -h container quay.io/podman/stable
[root@container /]# curl -Lso /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
[root@container /]# chmod +x /usr/local/bin/kind
[root@container /]# kind create cluster --retain
enabling experimental podman provider
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.33.1) 🖼 
 ✗ Preparing nodes 📦  
ERROR: failed to create cluster: command "podman run --name kind-control-plane --hostname kind-control-plane --label io.x-k8s.kind.role=control-plane --privileged --tmpfs /tmp --tmpfs /run --volume 2809683cde081bcd6ca6b9ddec29e071f416b03a41c52dcdf3b52262e1388a76:/var:suid,exec,dev --volume /lib/modules:/lib/modules:ro -e KIND_EXPERIMENTAL_CONTAINERD_SNAPSHOTTER --detach --tty --net kind --label io.x-k8s.kind.cluster=kind -e container=podman --cgroupns=private --publish=127.0.0.1:42583:6443/tcp -e KUBECONFIG=/etc/kubernetes/admin.conf docker.io/kindest/node@sha256:050072256b9a903bd914c0b2866828150cb229cea0efe5892e2b644d5dd3b34f" failed with error: exit status 125
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
[root@container /]# kind delete cluster
enabling experimental podman provider
Deleting cluster "kind" ...
Deleted nodes: ["kind-control-plane"]
[root@container /]# kind create cluster --retain
enabling experimental podman provider
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.33.1) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✗ Starting control-plane 🕹️ 
ERROR: failed to create cluster: failed to init node with kubeadm: command "podman exec --privileged kind-control-plane kubeadm init --config=/kind/kubeadm.conf --skip-token-print --v=6" failed with error: exit status 1
Command Output: I0522 07:40:50.280575     168 initconfiguration.go:261] loading configuration from "/kind/kubeadm.conf"
W0522 07:40:50.281023     168 common.go:101] your configuration file uses a deprecated API spec: "kubeadm.k8s.io/v1beta3" (kind: "ClusterConfiguration"). Please use 'kubeadm config migrate --old-config old-config-file --new-config new-config-file', which will write the new, similar spec using a newer API version.
[...]
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests"
[kubelet-check] Waiting for a healthy kubelet at http://127.0.0.1:10248/healthz. This can take up to 4m0s
[kubelet-check] The kubelet is not healthy after 4m0.000619259s
[...]
The HTTP call equal to 'curl -sSL http://127.0.0.1:10248/healthz' returned error: Get "http://127.0.0.1:10248/healthz": context deadline exceeded
[...]
```

The `podman logs kind-control-plane` now has just systemd startup
messages but we can continue the debugging with
```
[root@container /]# podman exec kind-control-plane journalctl -l
```
where
```
May 22 07:40:54 kind-control-plane kubelet[208]: E0522 07:40:54.254703     208 kubelet.go:570] "Failed to create an oomWatcher (running in UserNS, Hint: enable KubeletInUserNamespace feature flag to ignore the error)" err="open /dev/kmsg: operation not permitted"
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
 ✓ Ensuring node image (kindest/node:v1.33.1) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
```

We can then use
```
[root@container /]# podman exec kind-control-plane kubectl get all -A
```
to check what's in the Kubernetes-in-podman-in-podman cluster by
default.

## Automate the initial investigation

Based on the above investigation, we can use a `Dockerfile`
```
FROM quay.io/podman/stable
RUN curl -Lso /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
RUN chmod +x /usr/local/bin/kind
RUN sed -i 's/utsns=.*/utsns="private"/; s/cgroups=.*/cgroups="enabled"/' /etc/containers/containers.conf
COPY kind-cluster-rootless.yaml /etc/kind-cluster-rootless.yaml
ENV KIND_EXPERIMENTAL_PROVIDER podman

```
to build a container image which could be used in various scenarios.

The basic use then changes to

```
$ podman build -t localhost/kind .
$ podman run -ti --privileged --name kind localhost/kind \
    kind create cluster --config /etc/kind-cluster-rootless.yaml
```

Since the command now recommends
```
Set kubectl context to "kind-kind"
You can now use your cluster with:
kubectl cluster-info --context kind-kind
```
we can add the Kubernetes client to the container image and try that.
However, with the `kind create cluster` command finishing, the
container stopped as well. We might want to set the `ENTRYPOINT`
to just infinite sleep, recreate the container with just
```
$ podman run -d --privileged --name kind localhost/kind
```
and then `podman exec` the commands in it.

## Persistence

So far all the configuration and images used by the cluster were
stored in the overlay layer of the container. The next step is
therefore to isolate it to a data volume. The criteria of success is to
be able to run the container as read only, and remove and recreate it
with the data volume while not losing the status.

Since podman stores most everything under `/var/lib/containers`,
a good start would be
```
$ podman volume create kind-data
$ podman run -d --privileged --name kind -v kind-data:/var/lib/containers localhost/kind
$ podman exec -ti kind kind create cluster ...
```

We can then try that the cluster works, remove and recreate
the container, and manually run the podman container in that container again:
```
$ podman exec -ti kind kubectl get all -A
$ podman rm -f kind
$ podman run -d --privileged --name kind -v kind-data:/var/lib/containers localhost/kind
$ podman exec -ti kind podman start --all
$ podman exec -ti kind kubectl get all -A
```

We will likely get error message like
```
E1206 07:37:22.311932    1668 memcache.go:265] couldn't get current server API group list: Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
```
at this point. It's because the kubeconfig generated by
`kind create cluster` got stored in the container in `/root/.kube/config`
and thus got lost when the container got removed.

Luckily the environment variable `KUBECONFIG` is used both by `kubectl`
and by `kind create cluster`, so setting it to point to a location
under the now persistent `/var/lib/containers/` makes things work.

The last step in the persistence story is adding `--read-only` to
the `podman run` parameters. This serves as a safeguard against some
of the vital configuration or data being stored outside of the mounted
volume, and thus getting lost when the container is removed and
recreated.

## Access to the API server

By default the API server runs on a randomly assigned port in the
podman cluster:
```
$ podman exec -ti kind kubectl cluster-info --context kind-kind
Kubernetes control plane is running at https://127.0.0.1:33997
```

By using a [Cluster config](kind-cluster.yaml) with `apiServerPort`
specified, we can have the value consistent, easier to then publish
it outside of the podman in the future.

## Running in a K3s setup

With the basic **kind** operation verified with plain podman, we can
replicate the same setup in a K3s pod. The
[kind-cluster-pod-k3s.yaml](kind-cluster-pod-k3s.yaml) shows an
example Pod. The `image` is defined as `localhost/kind` there so it
needs to be built and then `k3s ctr images import`ed for K3s to be
able to use the image.

Then it should be a matter of
```
$ kubectl apply -f - < kind-cluster-pod-k3s.yaml
```
and checking the progress with
```
$ kubectl logs -f pod/kind-cluster -c create-cluster
$ kubectl logs pod/kind-cluster
```

Eventually,
```
$ kubectl exec pod/kind-cluster -- kubectl get all -A
```
will show a **kind** Kubernetes cluster withing a K3s Kubernetes
cluster.

As with podman where we used `--read-only`, in Kubernetes we want to
use `readOnlyRootFilesystem: true`. It requires a bit of special
handling, mounting `emptyDir` volumes to `/run` and `/tmp` and setting
`TMPDIR=/tmp` to avoid the use of `/var/tmp`.

To be able to access the API server from outside of the Pod,
we define the `apiServerAddress` as 0.0.0.0, with Service giving
it a static IP address in the cluster.

To authenticate, we can create for example a separate cluster-admin Service
Account and use its token to access the API server of the **kind**
cluster:
```
$ kubectl exec pod/kind-cluster -- kubectl create serviceaccount -n default admin
$ kubectl exec pod/kind-cluster -- \
    kubectl patch clusterrolebinding cluster-admin --type=json \
    -p='[{"op":"add", "path":"/subjects/-", "value":{"kind":"ServiceAccount", "namespace":"default", "name":"admin" } }]'
$ KIND_ADDR=$(kubectl get service/kind-cluster -o jsonpath='{.spec.clusterIP}:{.spec.ports[0].port}')
$ kubectl --kubeconfig=./kubeconfig config set-cluster kind \
    --server=https://$KIND_ADDR --insecure-skip-tls-verify=true
$ kubectl --kubeconfig=./kubeconfig config set-credentials kind-admin \
    --token=$(kubectl exec pod/kind-cluster -- kubectl create token -n default admin)
$ kubectl --kubeconfig=./kubeconfig config set-context kind --cluster=kind --user=kind-admin
$ kubectl --kubeconfig=./kubeconfig config use-context kind
$ kubectl --kubeconfig=./kubeconfig get all -A
```
