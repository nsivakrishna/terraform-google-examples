# Kubernetes Cluster on GCE Example

**Figure 1.** *diagram of Google Cloud resources*

![architecture diagram](./diagram.png)

## Set up the environment

```
gcloud auth application-default login
export GOOGLE_PROJECT=$(gcloud config get-value project)
```

## Run Terraform

```
terraform init
terraform plan
terraform apply
```

SSH into master through the nat gateway

```
gcloud compute ssh --ssh-flag="-A" \
  $(gcloud compute instances list --filter=nat-gateway-us-central --uri) \
  -- ssh $(gcloud compute instances list --filter='name~k8s-.*master.*' --format='get(name)')
```

Configure kubectl:

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Wait for all nodes to join and become Ready:

```
kubectl get nodes -o wide
```

## Run Example App with HTTP LoadBalancer

```
kubectl run nginx --image nginx --port 80
kubectl expose deployment nginx --port 80 --type=NodePort
```

```
kubectl create -f - <<'EOF'
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: basic-ingress
spec:
  backend:
    serviceName: nginx
    servicePort: 80
EOF
```

## Cleanup

Remove all resources created by terraform:

```
terraform destroy
```