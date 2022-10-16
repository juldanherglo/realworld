# Architecture
![Architecture](docs/toptal-takehome-arch.png "Architecture")
As shown in the picture, we have VPC which get divided into public/private/db
subnet groups. Each group has three subnets for three availability zones.

In the public zones we have a network load balancer that works as an ingress
for the kubernetes cluster.  Additionally, we have NAT gateways so that the
ec2 / pods in the private subnets can talk to the internet and e.g. download
container images.

The node-group for the eks cluster lives in the private subnets. It is auto-scaled by [karpenter](https://karpenter.sh/).
The cluster is configured that the control plane and all the pods are synced to cloudwatch logs.

In the DB subnets we have a multi-az RDS which automatically creates backups every night.
The DB writes its logs to cloudwatch logs as well.


# TODOs
* have an official DNS domain with official tls certificate
* have external monitoring to the URL e.g. [pingdom](https://www.pingdom.com/)
* tune requests/limits of the pods
* currently the eks api endpoint is public. In a real production scenario, the
  api endpoint should be restricted to the VPC. Since terraform needs to reach
  the endpoint, we need to introduce e.g. a bastion host.
* fine tune security groups and NACLs to allow only the necessary access and
  block everything else
* reconfigure the app so that it uses ssl encryption when talking to the RDS
