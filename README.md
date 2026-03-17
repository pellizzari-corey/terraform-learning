# terraform-learning

A progressive Terraform learning repo targeting AWS — Networking + Serverless,
built around reusable modules.

## Learning Path

| Project | Focus | Key Concepts |
|---|---|---|
| [01-remote-state](./projects/01-remote-state/README.md) | Provider + S3/DynamoDB backend | init, plan, apply, state, outputs |
| [02-flat-vpc](./projects/02-flat-vpc/README.md) | VPC, subnets, IGW, route tables, SGs | data sources, resource dependencies |
| [03-vpc-module](./projects/03-vpc-module/README.md) | Refactor VPC into a reusable module | module blocks, input/output contracts |
| [04-lambda-module](./projects/04-lambda-module/README.md) | Lambda + IAM as a module | IAM, archive_file, environment vars |
| 05-api-gateway-module *(TBD)* | HTTP API wired to Lambda | integrations, stages, CORS |
| 06-serverless-api *(TBD)* | Compose all modules into a real app | module composition, remote state data |
| 07-multi-env *(TBD)* | dev / prod via tfvars | workspaces vs var files |

## Prerequisites

- Terraform >= 1.6 (`brew install terraform` or [tfenv](https://github.com/tfutils/tfenv))
- AWS CLI configured (`aws configure`)
- An IAM principal with permissions for the services in each project

## Repo Structure

```
terraform-learning/
├── .gitignore
├── README.md
├── modules/              ← Reusable modules (built in Phase 2+)
│   ├── vpc/
│   ├── lambda/
│   └── api_gateway/
└── projects/             ← One directory per learning project
    ├── 01-remote-state/
    ├── 02-flat-vpc/
    └── ...
```
