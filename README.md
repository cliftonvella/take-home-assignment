## Setup Description

Both the infrastructure and Kubernetes deployments are being handled through Terraform, which is my IAC tool of choice for this task. The rationale for this approach is the following:

* I went with EKS for the Kuberenetes cluster

* It's easier to reference resource ARNs and properties for the EKS cluster, security groups, subnets, TLS certificate, and so on as Terraform is deploying the infrastructure and so is aware of all the resource data

* Given the amount of time I could allocate for this task, I did not have time to implement a tool like ArgoCD or Kustomize to handle the Kubernetes deployments following GitOps principles

## How is the code structured?

* Where possible (and where it makes sense) the infrastructure code is modular, and the deployment is repeatable across any new environment just by adding a new TFVars file with the correct name structure.

* The VPC subnet can be found in the `cidr_blocks` module. Subnets for any new deployments can be added here, separated by region, project and environments for that project.

* VPC and subnetting is handled by `vpc_subnetting.tf`, which calls the VPC and subnet modules. Apart from a VPC and associated PHZ, for resilience purposes this deploys various sets of subnets across multiple AZs (see the variable `az_count` in the TFVars file). Subnets are structured as follows:
  * `lb_subnets` - these are used for public-facing ALBs and are public subnets. Tags are applied for the LB controller to be able to identify which subnets to deploy the ALB on.
  * `lb subnets_internal` - these are used for internal ALBs and have no internet access. Tags are applied for the LB controller to be able to identify which subnets to deploy the ALB on.
  * `nat_subnets` - these are subnets associated with the NAT gateways. The attribute `nat_required` set to `true`ensures that one NAT gateway gets created per subnet. The default route for these subnets is the internet gateway, which gets created by the VPC module when setting the attribute `public` to `true`
  * `private_subnets` - these are subnets that get internet access via the NAT gateways. Both the EKS cluster and its worker nodes are deployed on these subnets such that they remain protected from direct external access

* A public R53 zone is deployed in `route53.tf`. Note that for the purposes of this task this is a dummy zone. When testing this deployment I used one of our existing R53 public zones, both to actually be able to reach the public endpoint for the app as well as to be able to validate the ACM certificate used on the public-facing ALB. The certificate is deployed through the `acm.tf` file.

* The EKS cluster deployment is handled by `eks_cluster.tf`, which calls the `eks_cluster` module. This module handles:
  * The deployment of the EKS cluster, node group and EKS nodes
  * Creation of security groups for the EKS cluster, node group and ALBs. The rules are passed in as a list from the calling module
  * Controllers for the cluster autoscaler and load balancer and their service accounts
  * IAM roles and IAM policies required for the EKS cluster control plane to be able to manage cluster resources, for the cluster autoscaler and load balancer controller to be able to work, and for fluent-bit to be able to send logs to a Cloudwatch log group (+ a service account for fluent-bit)
  * The deployment of the metrics server, required for the horizontal pod autoscaler to be able to work.

* I'm also deploying a set of bastion hosts, which can for example be used to tunnel through to reach the worker nodes over SSH, and potentially also for reaching the EKS cluster remotely with kubectl using methods like port forwarding over SSM. The bastion hosts are assigned EIPs and DNS records so that they are accessible over the internet from a whitelist of public IPs.

* The deployment manifests can be found in `deployments.tf` as terraform resources. I also provided a set of deployment manifests in YAML format for easier readability.

## Kubernetes Deployments

* A deployment for the httpbin app, which contains:
  * 3 replicas for redundancy
  * A strategy for rolling updates which ensures that there's always at least 3 pods handling traffic (particularly important for high traffic situations)
  * Resource and request limits on the containers, which helps to avoid destabilising pod and node health
  * Liveness and readiness probes for the containers, which ensure the service is healthy before it can receive traffic
  * An example of a fluent-bit sidecar container to be able to send app logs to Cloudwatch. The httpbin container and the fluent-bit container share the log volume. The config for the fluent-bit container is obtained via a config map.

* Services that expose the containers on TCP/80 (HTTP). I've deployed separate ones for public and internal services, which will be referenced in the ALB deployments

* Ingress services that deploy:
  * A public-facing ALB, secured with its own security group, deployed on `lb_subnets`, with an HTTPS listener which uses the ACM-issued TLS certificate mentioned earlier. The listener has a rule that redirects traffic from `app.<your-public-domain>/get` to the httpbin-public service. The public endpoint is only accessible from a whitelist of public IPs.
  * An internal ALB, again secured with its own security group, deployed on `lb_subnets_internal` with an HTTP listener with a rule that redirects traffic from `app.<your-internal-domain>/post` to the httpbin-internal service. This service is only accessible internally.
  * DNS records for each of the endpoints

* A horizontal pod autoscaler, which:
  * Ensures the minimum number and maximum number of replicas. This would obviously need to be adjusted accordingly depending on the requirements
  * What metrics to watch for before scaling pods up and down
  * The scale up and scale down behaviour. Again, these propertes would need to be adjusted accordingly depending on the requirements

* A network policy which provides an additonal layer of security at cluster level:
  * Allows access to the pods only from within the VPC
  * Contains a placeholder ingress rule which limits access to the pods only from specific namespaces

## How to deploy

* The terraform state file is stored in an S3 bucket. The folder structure in the state file bucket ensures clear segregation between state files belonging to different deployments.

* Deployments are done by calling the Makefile and passing in some variables. A typical deployment, with variables related to this task, and assuming you have the proper AWS credentials in place in your environment, would be as follows:

  * To initialise terraform's working directory and setup the backend:
    ```
    make init INSTANCE=fft AWS_REGION=eu-central-1 OU=eks ACCOUNT=eks-test ENV=dev
    ```
  * To run a plan:
    ```
    make plan INSTANCE=fft AWS_REGION=eu-central-1 OU=eks ACCOUNT=eks-test ENV=dev
    ```
  * To apply:
    ```
    make apply PLAN_FILE=fft_casino_eks-test_dev.plan APPROVE=yes
    ```
  * To destroy the environment:
    ```
    make destroy INSTANCE=fft AWS_REGION=eu-central-1 OU=eks ACCOUNT=eks-test ENV=dev
    ```
    Then re-apply as per above
* Through the Makefile, you can also run `make format` to remove any formatting errors from the code

## Improvements

* The Kubernetes deployments in `deployments.tf` can probably be templated and the code can be transferred into a deployment module, which can then be called from the root module by passing in the necessary variables.

* Through the setup of proper IAM policies and roles, Terraform should only be able to assume a __Plan-Only__ role when running a plan locally, which only has the necessary permissions to run a terraform plan, and is not able to deploy. Only the deployment pipeline (e.g. through Jenkins), should be able to assume the deployment role with Administrator permissions. I've included an example this in `main.tf` for the AWS provider but left it commented out.

* All the Kubernetes deployments are deployed to the default namespace. This is not good practice in production environments. App containers, monitoring containers, and so on should be in their own namespaces when possible.

* Pod disruption budget rules and node affinity rules can be implemented to further enhance fault-tolerance and high availability respectively

* A Prometheus setup can be implemented to scrape cluster metrics, which can then be used as a data source in a Grafana instance where dashboards displaying relevant metrics can be set up. I would choose this over something like EKS container insights, as the Prometheus / Grafana combo is not only vendor-agnostic, but will also probably end up being more cost-effective.

* The same applies about sending to the application logs from fluent-bit to Cloudwatch over something like an ELK stack or a Loki instance. 
