# Delivering the example with a canary release using ArgoCD

## Install Argo Rollout

You can install [Argo Rollouts](https://argoproj.github.io/argo-rollouts/concepts/#concepts) to your cluster by following the [documentation](https://argoproj.github.io/argo-rollouts/installation/#installation).

For your convenience, the installation commands are given below :

```
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://raw.githubusercontent.com/argoproj/argo-rollouts/stable/manifests/install.yaml
```

You can also install the [Argo Rollouts kubectl plugin](https://argoproj.github.io/argo-rollouts/installation/#kubectl-plugin-installation) :

```
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
sudo chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
kubectl argo rollouts version
```

## Create a project

```
kubectl create ns delivery-simplenode-prod
helm install hs-rollout . -n delivery-simplenode-prod
```

## Find our current rollout with the command line

```
kubectl argo rollouts list rollouts -n delivery-simplenode-prod
```

## Watch the current rollout on the command line

```
kubectl argo rollouts get rollout simplenode-prod  -w -n delivery-simplenode-prod
```

## Update the release in the values file

```
helm upgrade hs-rollout . -n delivery-simplenode-prod --set image.tag=2.0.0
```

## Manually promote the rollout after the first canary steps

```
kubectl argo rollouts promote simplenode-prod -n delivery-simplenode-prod
```
