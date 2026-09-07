# ADR-0005: Secrets Manager is reached through a VPC interface endpoint

- **Status:** Proposed
- **Date:** 2026-09-07
- **Deciders:** Rafael Costa
- **Related:** ADR-0004 (Scaffolder runs as a container on EKS)

## Context

The shared VPC (`infra/modules/aws/vpc`) has two private subnets, one in
`us-east-1a` and one in `us-east-1b`, and every workload runs in them. AWS API
calls from those subnets leave by one of two paths: an interface endpoint where
one exists, or the NAT gateway where one does not. Endpoints exist today for
SQS, ECR API, ECR Docker, CloudWatch Logs and SSM, plus an S3 gateway endpoint
for ECR layer pulls. Everything else takes the NAT gateway to a public AWS
service endpoint.

Secrets Manager had no endpoint, and it now carries the platform's most
sensitive traffic. The scaffolder's `github` worker reads the GitHub App PEM
private key from Secrets Manager at pod startup
(`infra/live/scaffolder/dev/main.tf`), and that key can create and write
repositories across the organisation. ADR-0004 built a trust boundary around it:
two Deployments of one image, two IRSA roles, and only the `github` role holding
`secretsmanager:GetSecretValue`. The identity half of that boundary is enforced;
the network half was not. The single call that transports the credential was the
one leaving the VPC.

Two constraints shape what can be done about it.

**The NAT gateway is load-bearing for non-AWS traffic.** The scaffolder calls
`api.github.com`, telemetry leaves the cluster for Datadog, and image pulls from
registries with no endpoint go the same way. Those have no AWS-network
equivalent.

**The secret is read once and cached.** The scaffolder fetches it at startup for
the pod's lifetime rather than per task (`services/scaffolder/CLAUDE.md`), so
the traffic volume involved is a few kilobytes per pod start. This decision
cannot be justified on data processing savings, and is not.

## Decision

We add a regional interface VPC endpoint for
`com.amazonaws.${var.aws_region}.secretsmanager` to the VPC module, attached to
every private subnet, using the existing `aws_security_group.endpoints` and with
private DNS enabled. It is declared alongside the other interface endpoints in
`infra/modules/aws/vpc/main.tf` and carries the same
`Project`/`Environment`/`Name` tags.

Private DNS means `secretsmanager.us-east-1.amazonaws.com` resolves inside the
VPC to the endpoint's per-AZ elastic network interfaces. No workload
configuration changes: the AWS SDKs keep their default regional endpoint and
their calls change path without changing code. An endpoint per subnet means each
AZ has a local ENI, so a pod does not cross an AZ boundary to reach the service
and the endpoint does not become a single-AZ dependency.

The endpoint carries no endpoint policy. No endpoint in this module has one, and
adding one here alone would introduce a second authorisation surface for a
single service while leaving the other five open. Access to the secret is
already constrained on both sides that matter: the IRSA policy grants
`GetSecretValue` on exactly one secret ARN to exactly one role, and the
pipeline's own role carries an explicit `Deny` on it. An endpoint policy would
restate that in a third place. It is the natural next step for defence in depth
and belongs in a change that applies it to every endpoint at once.

The KMS customer-managed key that encrypts the secret needs no endpoint of its
own. Secrets Manager performs the decrypt on the caller's behalf, and the IRSA
policy's `kms:Decrypt` grant is scoped with `kms:ViaService` to reflect exactly
that, so the pod issues no direct KMS API call.

The NAT gateway stays. This decision moves one service's traffic off it; it does
not remove the need for it.

## Consequences

**Security.** The credential path no longer leaves the VPC. Traffic to Secrets
Manager stays on the AWS network, gets a private IP inside the VPC CIDR, and is
constrained by the endpoint security group, which admits only TLS from inside
the VPC. The exposure removed is modest in absolute terms, since the call was
always TLS to an authenticated AWS endpoint, but it removes the internet from
the path of the one call that carries the platform's highest-value secret, and
it makes the network boundary agree with the identity boundary ADR-0004 built.
It also gives the traffic a shape that can be reasoned about: an endpoint policy
or VPC flow log analysis has something local to attach to.

**Limitations.** The endpoint is not an authorisation control. It restricts the
path, not the caller: anything in the VPC with valid credentials can reach
Secrets Manager through it, and without an endpoint policy it does not restrict
which secrets or which accounts. Nor does it prevent a workload from reaching
Secrets Manager some other way; it only makes the endpoint the route the SDK's
default resolution finds first.

**Cost.** An interface endpoint bills per AZ per hour plus per GB processed. In
`us-east-1` that is roughly $0.01 per AZ-hour, so two AZs is about $0.02/hour or
$15/month, and $0.01/GB on top. Traffic displaced from the NAT gateway saves
$0.045/GB, but the volume here is a few kilobytes per pod start, so the saving
rounds to nothing. This endpoint costs about $15/month and buys a network path,
not a reduction in bill. Unlike the SQS and ECR endpoints, which do pay for
themselves in displaced NAT data processing, this one is a security purchase and
should be judged as one.

**Operations.** Four things now have to hold for the scaffolder to start, where
one did before.

- *DNS.* Private DNS depends on `enable_dns_support` and `enable_dns_hostnames`
  on the VPC, both already set. If private DNS is ever disabled, resolution
  silently reverts to the public endpoint and the traffic quietly returns to the
  NAT gateway with no error to notice.
- *Route connectivity.* An interface endpoint is an ENI in a subnet, not a
  route. It works only for workloads in a subnet the endpoint is attached to,
  which is why it is attached to all private subnets rather than one. A future
  private subnet added without adding it to this endpoint gets the NAT path back.
- *Security groups.* The shared endpoint SG allows 443 from the VPC CIDR. A
  future tightening of that rule affects all six interface endpoints at once,
  and getting it wrong breaks pod startup for every service, not just the
  scaffolder.
- *IAM and availability.* IAM is unchanged: the endpoint grants nothing and
  denies nothing, and the existing IRSA policy is still the only thing that
  decides who can read the secret. The endpoint itself is an AWS-managed
  resource with an ENI per AZ; losing one AZ's ENI leaves the other serving,
  and losing the service means the scaffolder cannot start regardless of path.

Failures are also less legible than they were. A `GetSecretValue` that used to
fail on credentials can now also fail on DNS resolution, on a security group
rule, or on a subnet the endpoint is not attached to, and the SDK error does not
distinguish them.

## Alternatives considered

- **Keep using the NAT gateway.** Zero change, zero added cost, and the traffic
  is already TLS to an authenticated AWS endpoint. Rejected because the
  credential this call carries is the one whose blast radius ADR-0004 spent a
  second Deployment, a second queue and a second IAM role to contain, and
  leaving its transport on the public path is the inconsistent part of that
  design. $15/month is a small price for making the two boundaries agree.

- **Remove the NAT gateway once enough endpoints exist.** The version of this
  decision that actually saves money: drop the $0.045/hour gateway and force all
  egress through endpoints. Rejected because the platform's dependencies are not
  all AWS. The scaffolder's entire purpose is calling `api.github.com`,
  telemetry goes to Datadog, and neither has an AWS-network path. Removing the
  NAT gateway would break the scaffolder before it ever ships.

- **A centralised endpoint architecture.** One shared-services VPC owning the
  endpoints, with other VPCs reaching them over Transit Gateway or PrivateLink
  and resolving through Route 53 Resolver rules. This is how an organisation
  with many VPCs avoids paying per-AZ endpoint charges many times over.
  Rejected as unfounded here: the platform has exactly one VPC, so there is
  nothing to centralise, and the architecture would add a Transit Gateway, its
  attachments, its per-GB charges and a cross-account DNS story to save
  duplication that does not exist.

## When to revisit

- If a second VPC or a second account appears, the per-AZ endpoint cost starts
  multiplying and the centralised architecture becomes worth pricing.
- If any workload begins calling KMS directly rather than through Secrets
  Manager, a KMS endpoint is the matching change and the `ViaService` reasoning
  above no longer covers it.
- If endpoint policies are adopted for the module, this endpoint should get one
  restricting access to the scaffolder's secret ARN in the same change.
- If a workload ever needs to read a secret per request rather than at startup,
  the cost calculation changes from "buys nothing" to "displaces NAT data
  processing" and is worth redoing.
