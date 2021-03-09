# using-ecs-cli-tutorial-01

## Introduction

**The `ecs-cli` command is a little gem 💎**

👉 `ecs-cli` allows you to deploy a Docker stack very easily on AWS ECS using the same syntax as the [docker-compose](https://docs.docker.com/compose/compose-file/) file format version 1, 2 and 3

👉 The selling point of `ecs-cli` is to reuse your `docker-compose.yml` files to deploy your containers to AWS

👉 `ecs-cli` translates a `docker-compose-yml` to ECS Task Desfinitions and Services

**In this article we will explore how to:**

- Use the tool`ecs-cli` to create an AWS ECS cluster to orchestrate a set of Docker Containers
- Add observability to the cluster thanks to [AWS Cloud LogGroups](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)
- Use ecs-cli to deploy a set of Docker containers on the Cluster
- Leverage [AWS EFS](https://aws.amazon.com/efs/?sc_channel=PS&sc_campaign=acquisition_HK&sc_publisher=google&sc_medium=efs_b&sc_content=aws_efs_e&sc_detail=aws%20efs&sc_category=efs&sc_segment=161362669335&sc_matchtype=e&sc_country=HK&s_kwcid=AL!4422!3!161362669335!e!!g!!aws%20efs&ef_id=Cj0KCQiAs5eCBhCBARIsAEhk4r6RN6GGjzhCAGkdsaw_vwkR7dBQSXwikVvXc9QpJdTokCACooGDymgaAn2PEALw_wcB:G:s&s_kwcid=AL!4422!3!161362669335!e!!g!!aws%20efs) to add persistence to the Cluster and add support of stateful workloads

Amazon Elastic File System is a cloud storage service provided by Amazon Web Services designed to provide scalable, elastic, concurrent with some restrictions, and encrypted file storage for use with both AWS cloud services and on-premises resources

**As an example we will deploy a Docker stack composed of:**

- [HASURA](https://hasura.io/) : an open source-engine that gives you an instant GraphQL & Rest API
- PostgresSQL 13.2 for the persistence layer

## Target architecture



![illustrations/global-architecture.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/global-architecture.png)

## Docker stack

This Docker Stack will be deployed on the `AWS ECS Cluster`

![illustrations/docker-compose-stack.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/docker-compose-stack.png)

## 7 Steps

1. Install `ecs-cli`
2. Configure `ecs-cli`
3. Create the cluster Stack
4. Create a `Docker Compose Stack`
5. Deploy the docker compose stack on `AWS ECS`
6. Create an elastic filesystem `AWS EFS`
7. Add persistence to Postgres SQL thanks to `AWS EFS`

Prerequisites (for macOS)

- [jq](https://stedolan.github.io/jq/)
- [aws-cli](https://aws.amazon.com/cli/)
- [brew](https://brew.sh/)

## Step1 : Install `ecs-cli`

**The first step is to install the `ecs-cli` command on your system:**

The complete installation procedure for macOS, Linux and Windows is available with this [link](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html).

For macOS the installation procedure is as follows:

👉 Download `ecs-cli` binary

```bash
sudo curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-darwin-amd64-latest
```

👉 install [gnupg](https://gnupg.org/) (a free implementation of OpenPGP standard)

```bash
brew install gnupg
```

👉 get the public key of `ecs-cli` (I have copied the key in a GIST for simplicity)

```bash
https://gist.githubusercontent.com/raphaelmansuy/5aab3c9e6c03e532e9dcf6c97c78b4ff/raw/f39b4df58833f09eb381700a6a854b1adfea482e/ecs-cli-signature-key.key

```

👉 import the signature

```bash
gpg --import ./signature.key
```

👉 make `ecs-cli` executable

```bash
sudo chmod +x /usr/local/bin/ecs-cli
```

👉 verify the setup

```bash
ecs-cli --version
```

## Configure `ecs-cli` 👩‍🌾

**Prerequisite**

- AWS CLI v2 must be installed. If it's not the case you can follow these instructions on this [link](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
- You need to have an AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY with administrative privileges

To create your AWS_ACCESS_KEY_ID you can read this [documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)

Your environment variables must be configured with a correct pair of AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY

```bash
export AWS_ACCESS_KEY_ID="Your Access Key"
export AWS_SECRET_ACCESS_KEY="Your Secret Access Key"
export AWS_DEFAULT_REGION=us-west-2
```

The following script configure an ECS-profile called `tutorial` for a cluster named `tutorial-cluster` on the `us-west-2` region with a default launch type based on EC2 instances:

`configure.sh`

```bash
#!/bin/bash
set -e
PROFILE_NAME=tutorial
CLUSTER_NAME=tutorial-cluster
REGION=us-west-2
LAUNCH_TYPE=EC2
ecs-cli configure profile --profile-name "$PROFILE_NAME" --access-key "$AWS_ACCESS_KEY_ID" --secret-key "$AWS_SECRET_ACCESS_KEY"
ecs-cli configure --cluster "$CLUSTER_NAME" --default-launch-type "$LAUNCH_TYPE" --region "$REGION" --config-name "$PROFILE_NAME"
```

## Step2 : Creation of an ECS-Cluster 🚀

We will create an ECS-Cluster based on ec2 instance.

ECS allows 2 launch types `EC2` and `FARGATE`

- EC2 (Deploy and manage your own cluster of EC2 instances for running the containers)
- AWS Fargate (Run containers directly, without any EC2 instances)

**If we want to connect to the ec2 instances with ssh we need to have a key pair**

👉 Creation of a key pair called `tutorial-cluster` :

```bash
aws ec2 create-key-pair --key-name tutorial-cluster \
 --query 'KeyMaterial' --output text > ~/.ssh/tutorial-cluster.pem
```

👉 Creation of the Cluster `tutorial-cluster` with 2 ec2-instances t3.medium

`create-cluster.sh`

```bash
#!/bin/bash
KEY_PAIR=tutorial-cluster
    ecs-cli up \
      --keypair $KEY_PAIR  \
      --capability-iam \
      --size 2 \
      --instance-type t3.medium \
      --tags project=tutorial-cluster,owner=raphael \
      --cluster-config tutorial \
      --ecs-profile tutorial
```

We have added 2 tags `project=tutorial` and `owner=raphael` to easily identify the resources created by the command

👉 Result

```bash
INFO[0006] Using recommended Amazon Linux 2 AMI with ECS Agent 1.50.2 and Docker version 19.03.13-ce
INFO[0007] Created cluster                               cluster=tutorial-cluster region=us-west-2
INFO[0010] Waiting for your cluster resources to be created...
INFO[0010] Cloudformation stack status                   stackStatus=CREATE_IN_PROGRESS
INFO[0073] Cloudformation stack status                   stackStatus=CREATE_IN_PROGRESS
INFO[0136] Cloudformation stack status                   stackStatus=CREATE_IN_PROGRESS
VPC created: vpc-XXXXX
Security Group created: sg-XXXXX
Subnet created: subnet-AAAA
Subnet created: subnet-BBBB
Cluster creation succeeded.
```

**This command create:**

- A new public VPC
  - An internet gateway
  - The routing tables
- 2 public subnets in 2 availability zones
- 1 security group
- 1 autoscaling group
  - 2 ec2 instances
- 1 ecs cluster

![illustrations/Screen_Shot_2021-03-08_at_11.36.36.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/Screen_Shot_2021-03-08_at_11.36.36.png)

We can now deploy a sample Docker application on the newly created ECS Cluster:

👉 Create a file called `docker-compose.yml`

```bash
version: "3"
services:
  webdemo:
    image: "amazon/amazon-ecs-sample"
    ports:
      - "80:80"

```

This stack can best tested locally

```bash
docker-compose up
```

Results:

latest: Pulling from amazon/amazon-ecs-sample
Digest: sha256:36c7b282abd0186e01419f2e58743e1bf635808231049bbc9d77e59e3a8e4914
Status: Downloaded newer image for amazon/amazon-ecs-sample:latest

![illustrations/Screen_Shot_2021-03-08_at_13.01.06.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/Screen_Shot_2021-03-08_at_13.01.06.png)

👉 We can now deploy this stack on AWS ECS:

```bash
ecs-cli compose --project-name tutorial  --file docker-compose.yml \
--debug service up  \
--deployment-max-percent 100 --deployment-min-healthy-percent 0 \
--region us-west-2 --ecs-profile tutorial --cluster-config tutorial
```

👉 To verify that the service is running we can use this command:

```bash
ecs-cli ps
```

Results:

```bash
Name                                                       State    Ports                     TaskDefinition  Health
tutorial-cluster/2e5af2d48dbc41c1a98/webdemo  RUNNING  34.217.107.14:80->80/tcp  tutorial:2      UNKNOWNK
```

The stack is deployed and accessible with the IP address `34.217.107.14`

👉 We can now browse the deployed Website:

```bash
open http://34.217.107.14
```

👉 Open the port 22 to connect to the EC2 instances of the cluster

```bash

# Get my IP
myip="$(dig +short myip.opendns.com @resolver1.opendns.com)"

# Get the security group
sg="$(aws ec2 describe-security-groups   --filters Name=tag:project,Values=tutorial-cluster | jq '.SecurityGroups[].GroupId')"

# Add port 22 to the Security Group of the VPC
aws ec2 authorize-security-group-ingress \
        --group-id $sg \
        --protocol tcp \
        --port 22 \
        --cidr "$myip/32" | jq '.'
```

👉 Connection to the instance

```bash
chmod 400 ~/.ssh/tutorial-cluster.pem
ssh -i ~/.ssh/tutorial-cluster.pem ec2-user@34.217.107.14
```

👉 Once we are connected to the remoter server: we can observe the running containers:

```bash
docker ps
```

```bash
CONTAINER ID        IMAGE                            COMMAND                  CREATED             STATUS                    PORTS                NAMES
7deaa49ed72c        amazon/amazon-ecs-sample         "/usr/sbin/apache2 -…"   2 minutes ago       Up 2 minutes              0.0.0.0:80->80/tcp   ecs-tutorial-3-webdemo-9cb1a49483a9cfb7b101
cd1d2a9807d4        amazon/amazon-ecs-agent:latest   "/agent"                 55 minutes ago      Up 55 minutes (healthy)                        ecs-agent
```

## Step3 : Adding observability 🤩

If we want to collect the logs for my running instances, we can create AWS CloudWatch Log Groups.

For that we can modify the `docker-compose.yml` file:

```bash
version: "2"
services:
  webdemo:
    image: "amazon/amazon-ecs-sample"
    ports:
      - "80:80"
    logging:
      driver: awslogs
      options:
         awslogs-group: tutorial
         awslogs-region: us-west-2
         awslogs-stream-prefix: demo
```

👉 And then redeploy the service with a create-log-groups option

```bash
ecs-cli compose --project-name tutorial  --file docker-compose.yml \
--debug service up  \
--deployment-max-percent 100 --deployment-min-healthy-percent 0 \
--region us-west-2 --ecs-profile tutorial --cluster-config tutorial \
--create-log-groups
```

![illustrations/Screen_Shot_2021-03-08_at_15.07.28.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/Screen_Shot_2021-03-08_at_15.07.28.png)

👉 We can now delete the service 🗑

```bash

ecs-cli compose --project-name tutorial  --file docker-compose.yml \
--debug service down  \
--region us-west-2 --ecs-profile tutorial --cluster-config tutorial

```

## 👉 Deploying a more complex stack

We are now ready to deploy [HASURA](https://hasura.io/) and [Postgres](https://www.postgresql.org/)

![illustrations/docker-compose-hasura.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/docker-compose-hasura.png)

`docker-compose.yml`

```bash
version: '3'
services:
  postgres:
    image: postgres:12
    restart: always
    volumes:
    - db_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: postgrespassword
  graphql-engine:
    image: hasura/graphql-engine:v1.3.3
    ports:
    - "80:8080"
    depends_on:
    - "postgres"
    restart: always
    environment:
      HASURA_GRAPHQL_DATABASE_URL: postgres://postgres:postgrespassword@postgres:5432/postgres
      ## enable the console served by server
      HASURA_GRAPHQL_ENABLE_CONSOLE: "true" # set to "false" to disable console
      ## enable debugging mode. It is recommended to disable this in production
      HASURA_GRAPHQL_DEV_MODE: "true"
      HASURA_GRAPHQL_ENABLED_LOG_TYPES: startup, http-log, webhook-log, websocket-log, query-log
      ## uncomment next line to set an admin secret
      # HASURA_GRAPHQL_ADMIN_SECRET: myadminsecretkey
volumes:
  db_data:
```

👉 We can test the stack locally:

```bash
docker-compose up &
```

Then

```bash
open localhost
```

![illustrations/Screen_Shot_2021-03-08_at_15.25.17.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/Screen_Shot_2021-03-08_at_15.25.17.png)

👉 We can now deploy this stack on AWS ECS

But before that we need to update the file `docker-compose.yml`

**We must add:**

- A `logging` directive
- A `links` directive

![illustrations/docker-compose-hasura-step2.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/docker-compose-hasura-step2.png)

```bash
version: '3'
services:
  postgres:
    image: postgres:12
    restart: always
    volumes:
    - db_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: postgrespassword
    logging:
      driver: awslogs
      options:
         awslogs-group: tutorial
         awslogs-region: us-west-2
         awslogs-stream-prefix: hasura-postgres
  graphql-engine:
    image: hasura/graphql-engine:v1.3.3
    ports:
    - "80:8080"
    depends_on:
    - "postgres"
    links:
      - postgres
    restart: always
    environment:
      HASURA_GRAPHQL_DATABASE_URL: postgres://postgres:postgrespassword@postgres:5432/postgres
      ## enable the console served by server
      HASURA_GRAPHQL_ENABLE_CONSOLE: "true" # set to "false" to disable console
      ## enable debugging mode. It is recommended to disable this in production
      HASURA_GRAPHQL_DEV_MODE: "true"
      HASURA_GRAPHQL_ENABLED_LOG_TYPES: startup, http-log, webhook-log, websocket-log, query-log
      ## uncomment next line to set an admin secret
      # HASURA_GRAPHQL_ADMIN_SECRET: myadminsecretkey
    logging:
      driver: awslogs
      options:
         awslogs-group: tutorial
         awslogs-region: us-west-2
         awslogs-stream-prefix: hasura
volumes:
  db_data:
```

We need to create a file called `ecs-params.yml` to specify extra parameters:

```bash

version: 1
task_definition:
  ecs_network_mode: bridge
```

This file will be used by the `ecs-cli` command.

👉 we can then launch the stack:

```bash
ecs-cli compose --project-name tutorial  --file docker-compose.yml \
 --debug service up  \
--deployment-max-percent 100 --deployment-min-healthy-percent 0 \
  --region us-west-2 --ecs-profile tutorial \
--cluster-config tutorial --create-log-groups
```

Results:

```bash
DEBU[0000] Parsing the compose yaml...
DEBU[0000] Docker Compose version found: 3
DEBU[0000] Parsing v3 project...
WARN[0000] Skipping unsupported YAML option for service...  option name=restart service name=postgres
WARN[0000] Skipping unsupported YAML option for service...  option name=depends_on service name=graphql-engine
WARN[0000] Skipping unsupported YAML option for service...  option name=restart service name=graphql-engine
DEBU[0000] Parsing the ecs-params yaml...
DEBU[0000] Parsing the ecs-registry-creds yaml...
DEBU[0000] Transforming yaml to task definition...
DEBU[0004] Finding task definition in cache or creating if needed  TaskDefinition="{\n  ContainerDefinitions: [{\n      Command: [],\n      Cpu: 0,\n      DnsSearchDomains: [],\n      DnsServers: [],\n      DockerSecurityOptions: [],\n      EntryPoint: [],\n      Environment: [{\n          Name: \"POSTGRES_PASSWORD\",\n          Value: \"postgrespassword\"\n        }],\n      Essential: true,\n      ExtraHosts: [],\n      Image: \"postgres:12\",\n      Links: [],\n      LinuxParameters: {\n        Capabilities: {\n\n        },\n        Devices: []\n      },\n      Memory: 512,\n      MountPoints: [{\n          ContainerPath: \"/var/lib/postgresql/data\",\n          ReadOnly: false,\n          SourceVolume: \"db_data\"\n        }],\n      Name: \"postgres\",\n      Privileged: false,\n      PseudoTerminal: false,\n      ReadonlyRootFilesystem: false\n    },{\n      Command: [],\n      Cpu: 0,\n      DnsSearchDomains: [],\n      DnsServers: [],\n      DockerSecurityOptions: [],\n      EntryPoint: [],\n      Environment: [\n        {\n          Name: \"HASURA_GRAPHQL_ENABLED_LOG_TYPES\",\n          Value: \"startup, http-log, webhook-log, websocket-log, query-log\"\n        },\n        {\n          Name: \"HASURA_GRAPHQL_DATABASE_URL\",\n          Value: \"postgres://postgres:postgrespassword@postgres:5432/postgres\"\n        },\n        {\n          Name: \"HASURA_GRAPHQL_ENABLE_CONSOLE\",\n          Value: \"true\"\n        },\n        {\n          Name: \"HASURA_GRAPHQL_DEV_MODE\",\n          Value: \"true\"\n        }\n      ],\n      Essential: true,\n      ExtraHosts: [],\n      Image: \"hasura/graphql-engine:v1.3.3\",\n      Links: [],\n      LinuxParameters: {\n        Capabilities: {\n\n        },\n        Devices: []\n      },\n      Memory: 512,\n      Name: \"graphql-engine\",\n      PortMappings: [{\n          ContainerPort: 8080,\n          HostPort: 80,\n          Protocol: \"tcp\"\n        }],\n      Privileged: false,\n      PseudoTerminal: false,\n      ReadonlyRootFilesystem: false\n    }],\n  Cpu: \"\",\n  ExecutionRoleArn: \"\",\n  Family: \"tutorial\",\n  Memory: \"\",\n  NetworkMode: \"\",\n  RequiresCompatibilities: [\"EC2\"],\n  TaskRoleArn: \"\",\n  Volumes: [{\n      Name: \"db_data\"\n    }]\n}"
DEBU[0005] cache miss                                    taskDef="{\n\n}" taskDefHash=4e57f367846e8f3546dd07eadc605490
INFO[0005] Using ECS task definition                     TaskDefinition="tutorial:4"
WARN[0005] No log groups to create; no containers use 'awslogs'
INFO[0005] Updated the ECS service with a new task definition. Old containers will be stopped automatically, and replaced with new ones  deployment-max-percent=100 deployment-min-healthy-percent=0 desiredCount=1 force-deployment=false service=tutorial
INFO[0006] Service status                                desiredCount=1 runningCount=1 serviceName=tutorial
INFO[0027] Service status                                desiredCount=1 runningCount=0 serviceName=tutorial
INFO[0027] (service tutorial) has stopped 1 running tasks: (task ee882a6a66724415a3bdc8fffaa2824c).  timestamp="2021-03-08 07:30:33 +0000 UTC"
INFO[0037] (service tutorial) has started 1 tasks: (task a1068efe89614812a3243521c0d30847).  timestamp="2021-03-08 07:30:43 +0000 UTC"
INFO[0074] (service tutorial) has started 1 tasks: (task 1949af75ac5a4e749dfedcb89321fd67).  timestamp="2021-03-08 07:31:23 +0000 UTC"
INFO[0080] Service status                                desiredCount=1 runningCount=1 serviceName=tutorial
INFO[0080] ECS Service has reached a stable state        desiredCount=1 runningCount=1 serviceName=tutorial
```

👉 And then we can verify that our container are running on AWS ECS Cluster

```bash
ecs-cli ps
```

Results

```bash
Name                                                              State                  Ports                       TaskDefinition  Health
tutorial-cluster/00d7ff5191dd4d11a9b52ea64fb9ee26/graphql-engine  RUNNING                34.217.107.14:80->8080/tcp  tutorial:10     UNKNOWN
tutorial-cluster/00d7ff5191dd4d11a9b52ea64fb9ee26/postgres        RUNNING                                            tutorial:10     UNKNOWN

```

👉 And then: 💪

```bash
open http://34.217.107.14
```

![illustrations/Screen_Shot_2021-03-08_at_16.09.29.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/Screen_Shot_2021-03-08_at_16.09.29.png)

👉 We can now stop the stack

```bash
ecs-cli compose down
```

To add persistent support to my solution we can leverage AWS EFS : Elastic File System

## Step 4: Add a persistent layer to my cluster

![illustrations/efs-file-system.png](https://elitizon-public.s3-us-west-2.amazonaws.com/blog/2021/09-03-deploy-a-dockerapp-on-aws-using-ecs-cli/illustrations/efs-file-system.png)

👉 Create an EFS file system named `hasura-db-file-system`

```bash
aws efs create-file-system \
    --performance-mode generalPurpose \
    --throughput-mode bursting \
    --encrypted \
    --tags Key=Name,Value=hasura-db-filesystem
```

Results:

```bash
{
    "OwnerId": "XXXXX",
    "CreationToken": "10f91a50-0649-442d-b4ad-2ce67f1546bf",
    "FileSystemId": "fs-5574bd52",
    "FileSystemArn": "arn:aws:elasticfilesystem:us-west-2:XXXXX:file-system/fs-5574bd52",
    "CreationTime": "2021-03-08T16:40:19+08:00",
    "LifeCycleState": "creating",
    "Name": "hasura-db-filesystem",
    "NumberOfMountTargets": 0,
    "SizeInBytes": {
        "Value": 0,
        "ValueInIA": 0,
        "ValueInStandard": 0
    },
    "PerformanceMode": "generalPurpose",
    "Encrypted": true,
    "KmsKeyId": "arn:aws:kms:us-west-2:XXXXX:key/97542264-cc64-42f9-954e-4af2b17f72aa",
    "ThroughputMode": "bursting",
    "Tags": [
        {
            "Key": "Name",
            "Value": "hasura-db-filesystem"
        }
    ]
}
```

👉 Add mount points to each subnet of the VPC:

```bash
aws ec2 describe-subnets --filters Name=tag:project,Values=tutorial-cluster \
 | jq ".Subnets[].SubnetId" | \
xargs -ISUBNET  aws efs create-mount-target \
 --file-system-id fs-5574bd52 --subnet-id SUBNET
```

The next step is to allow NFS connection from the VPC

We need first to get the security group associated with each mount target

```bash
	efs_sg=$(aws efs describe-mount-targets --file-system-id fs-5574bd52 \
	| jq ".MountTargets[0].MountTargetId" \
	 | xargs -IMOUNTG aws efs describe-mount-target-security-groups \
	 --mount-target-id MOUNTG | jq ".SecurityGroups[0]" | xargs echo )
```

👉 Then we need to open the TCP port 2049 for the security group of the VPC

```bash
vpc_sg="$(aws ec2 describe-security-groups  \
 --filters Name=tag:project,Values=tutorial-cluster \
 | jq '.SecurityGroups[].GroupId' | xargs echo)"

```

👉 Then we need to authorize the TCP/2049 port from the default security group of the VPC

```bash
aws ec2 authorize-security-group-ingress \
--group-id $efs_sg \
--protocol tcp \
--port 2049 \
--source-group $vpc_sg \
--region us-west-2

```

👉 We can now modify the `ecs-params.yml` to add persistence support:

- We use the ID of the EFS volume that has been created on the latest step : `fs-5574bd52`

```bash
version: 1
task_definition:
  ecs_network_mode: bridge
  efs_volumes:
    - name: db_data
      filesystem_id: fs-5574bd52
      transit_encryption: ENABLED
```

👉 Then we can redeploy our stack:

```bash
ecs-cli compose --project-name tutorial  --file docker-compose.yml \
 --debug service up  \
--deployment-max-percent 100 --deployment-min-healthy-percent 0 \
  --region us-west-2 --ecs-profile tutorial \
--cluster-config tutorial --create-log-groups
```

👉 Et voilà : the stack is operational 🎉 🦄 💪

## Summary

💪 We have deployed an ECS-CLI Cluster and launched a docker compose stack

🚀 The next step will be to expose and secure the stack using an AWS Application Load Balancer

The scripts associated with this article is available at

👉 [https://github.com/raphaelmansuy/using-ecs-cli-tutorial-01.git](https://github.com/raphaelmansuy/using-ecs-cli-tutorial-01.git)
