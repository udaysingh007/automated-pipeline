#!/bin/bash

# AWS Cost Resources Audit Script
# This script identifies resources that might be incurring charges in your AWS account

echo "==================================="
echo "AWS COST RESOURCES AUDIT"
echo "==================================="
echo "Scanning for resources that may incur charges..."
echo ""

# Function to check if AWS CLI is configured
check_aws_config() {
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "❌ AWS CLI not configured or no valid credentials found"
        exit 1
    fi
}

# Function to get current region
get_region() {
    aws configure get region 2>/dev/null || echo "us-east-1"
}

# Function to get all regions (for global resources)
get_all_regions() {
    aws ec2 describe-regions --query 'Regions[].RegionName' --output text
}

check_aws_config
CURRENT_REGION=$(get_region)
echo "Current region: $CURRENT_REGION"
echo "Account ID: $(aws sts get-caller-identity --query Account --output text)"
echo ""

# EC2 Instances
echo "🖥️  EC2 INSTANCES"
echo "=================="
instances=$(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name!=`terminated`].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output text --region $CURRENT_REGION)
if [[ -z "$instances" ]]; then
    echo "✅ No running EC2 instances found"
else
    echo "Instance ID          Type        State     Name"
    echo "------------------------------------------------"
    echo "$instances" | while read -r line; do
        if [[ -n "$line" ]]; then
            echo "$line"
        fi
    done
fi
echo ""

# RDS Instances
echo "🗄️  RDS INSTANCES"
echo "=================="
rds=$(aws rds describe-db-instances --query 'DBInstances[?DBInstanceStatus!=`deleted`].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus,Engine]' --output table --region $CURRENT_REGION 2>/dev/null)
if [[ "$rds" == *"None"* ]] || [[ -z "$rds" ]]; then
    echo "✅ No RDS instances found"
else
    echo "$rds"
fi
echo ""

# ELB/ALB Load Balancers
echo "⚖️  LOAD BALANCERS"
echo "=================="
# Classic Load Balancers
clb=$(aws elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text --region $CURRENT_REGION 2>/dev/null)
# Application/Network Load Balancers
alb=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code]' --output text --region $CURRENT_REGION 2>/dev/null)

echo "Classic Load Balancers:"
if [[ -z "$clb" ]]; then
    echo "✅ No Classic Load Balancers found"
else
    echo "Load Balancer Name"
    echo "------------------"
    echo "$clb"
fi

echo ""
echo "Application/Network Load Balancers:"
if [[ -z "$alb" ]]; then
    echo "✅ No Application/Network Load Balancers found"
else
    echo "Load Balancer Name     Type            State"
    echo "--------------------------------------------"
    echo "$alb"
fi
echo ""

# EBS Volumes
echo "💾 EBS VOLUMES"
echo "=============="
ebs=$(aws ec2 describe-volumes --query 'Volumes[?State!=`deleted`].[VolumeId,Size,VolumeType,State]' --output text --region $CURRENT_REGION)
if [[ -z "$ebs" ]]; then
    echo "✅ No EBS volumes found"
else
    echo "Volume ID              Size(GB)  Type      State"
    echo "----------------------------------------------"
    echo "$ebs"
fi
echo ""

# Elastic IPs
echo "🌐 ELASTIC IPs"
echo "=============="
eips=$(aws ec2 describe-addresses --query 'Addresses[].[PublicIp,AllocationId]' --output text --region $CURRENT_REGION)
if [[ -z "$eips" ]]; then
    echo "✅ No Elastic IPs found"
else
    echo "Public IP          Allocation ID"
    echo "--------------------------------"
    echo "$eips"
fi
echo ""

# NAT Gateways
echo "🌉 NAT GATEWAYS"
echo "==============="
nat=$(aws ec2 describe-nat-gateways --query 'NatGateways[?State!=`deleted`].[NatGatewayId,State,SubnetId]' --output text --region $CURRENT_REGION)
if [[ -z "$nat" ]]; then
    echo "✅ No NAT Gateways found"
else
    echo "⚠️  NAT Gateways found (each costs ~$45/month):"
    echo "NAT Gateway ID         State       Subnet"
    echo "----------------------------------------"
    echo "$nat" | while read -r line; do
        if [[ -n "$line" ]]; then
            echo "$line"
        fi
    done
fi
echo ""

# EKS Clusters
echo "☸️  EKS CLUSTERS"
echo "================"
eks=$(aws eks list-clusters --query 'clusters' --output table --region $CURRENT_REGION 2>/dev/null)
if [[ "$eks" == *"None"* ]] || [[ -z "$eks" ]]; then
    echo "✅ No EKS clusters found"
else
    echo "$eks"
    # Get details for each cluster
    for cluster in $(aws eks list-clusters --query 'clusters[]' --output text --region $CURRENT_REGION 2>/dev/null); do
        echo "Cluster: $cluster"
        aws eks describe-cluster --name "$cluster" --query 'cluster.[status,version]' --output table --region $CURRENT_REGION 2>/dev/null
        echo "Node groups:"
        aws eks list-nodegroups --cluster-name "$cluster" --query 'nodegroups' --output table --region $CURRENT_REGION 2>/dev/null
    done
fi
echo ""

# S3 Buckets (Global)
echo "🪣 S3 BUCKETS"
echo "============="
buckets=$(aws s3api list-buckets --query 'Buckets[].[Name,CreationDate]' --output text 2>/dev/null)
if [[ -z "$buckets" ]]; then
    echo "✅ No S3 buckets found"
else
    echo "Bucket Name           Created Date"
    echo "-----------------------------------"
    echo "$buckets"
    echo ""
    echo "Checking bucket sizes and storage classes..."
    for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null); do
        echo "📦 Bucket: $bucket"
        
        # Get bucket size and object count
        size_info=$(aws s3 ls s3://$bucket --recursive --summarize 2>/dev/null | tail -2)
        if [[ -n "$size_info" ]]; then
            echo "$size_info"
        else
            echo "   Empty or access denied"
        fi
        
        # Check if versioning is enabled (can increase costs)
        versioning=$(aws s3api get-bucket-versioning --bucket $bucket --query 'Status' --output text 2>/dev/null)
        if [[ "$versioning" == "Enabled" ]]; then
            echo "   ⚠️  Versioning: ENABLED (may increase costs)"
        fi
        echo ""
    done
fi
echo ""

# Lambda Functions
echo "λ LAMBDA FUNCTIONS"
echo "=================="
lambda=$(aws lambda list-functions --query 'Functions[].[FunctionName,Runtime,LastModified]' --output table --region $CURRENT_REGION 2>/dev/null)
if [[ "$lambda" == *"None"* ]] || [[ -z "$lambda" ]]; then
    echo "✅ No Lambda functions found"
else
    echo "$lambda"
fi
echo ""

# CloudFormation Stacks
echo "📚 CLOUDFORMATION STACKS"
echo "========================"
stacks=$(aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[].[StackName,StackStatus,CreationTime]' --output table --region $CURRENT_REGION 2>/dev/null)
if [[ "$stacks" == *"None"* ]] || [[ -z "$stacks" ]]; then
    echo "✅ No active CloudFormation stacks found"
else
    echo "$stacks"
fi
echo ""

# Route53 Hosted Zones (Global)
echo "🌍 ROUTE53 HOSTED ZONES"
echo "======================="
route53=$(aws route53 list-hosted-zones --query 'HostedZones[].[Name,Id,ResourceRecordSetCount]' --output table 2>/dev/null)
if [[ "$route53" == *"None"* ]] || [[ -z "$route53" ]]; then
    echo "✅ No Route53 hosted zones found"
else
    echo "$route53"
fi
echo ""

# VPC Endpoints
echo "🔗 VPC ENDPOINTS"
echo "================"
endpoints=$(aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[].[VpcEndpointId,ServiceName,State]' --output table --region $CURRENT_REGION 2>/dev/null)
if [[ "$endpoints" == *"None"* ]] || [[ -z "$endpoints" ]]; then
    echo "✅ No VPC endpoints found"
else
    echo "$endpoints"
fi
echo ""

# ElastiCache
echo "🔄 ELASTICACHE"
echo "=============="
elasticache=$(aws elasticache describe-cache-clusters --query 'CacheClusters[].[CacheClusterId,CacheClusterStatus,CacheNodeType]' --output table --region $CURRENT_REGION 2>/dev/null)
if [[ "$elasticache" == *"None"* ]] || [[ -z "$elasticache" ]]; then
    echo "✅ No ElastiCache clusters found"
else
    echo "$elasticache"
fi
echo ""

# Cost and Billing (if available)
echo "💰 CURRENT MONTH ESTIMATED COSTS"
echo "================================="
# Get current month costs (works on Linux and macOS)
if command -v gdate >/dev/null 2>&1; then
    # macOS with GNU date installed
    start_date=$(gdate -d "$(gdate +%Y-%m-01)" +%Y-%m-%d)
    end_date=$(gdate +%Y-%m-%d)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
    end_date=$(date +%Y-%m-%d)
else
    # macOS default date (limited functionality)
    start_date=$(date +%Y-%m-01)
    end_date=$(date +%Y-%m-%d)
fi

costs=$(aws ce get-cost-and-usage \
    --time-period Start=$start_date,End=$end_date \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
    --output text 2>/dev/null)

if [[ -n "$costs" ]] && [[ "$costs" != "None" ]] && [[ "$costs" != "null" ]]; then
    echo "Current month estimated cost: \${costs}"
else
    echo "⚠️  Could not retrieve cost information"
    echo "   This may be due to:"
    echo "   - Insufficient billing permissions"
    echo "   - Cost Explorer not enabled"
    echo "   - No costs to report yet this month"
fi
echo ""

echo "==================================="
echo "AUDIT COMPLETE"
echo "==================================="
echo "💡 TIP: Resources marked with ✅ are not incurring charges"
echo "⚠️  Review any resources listed above - they may be incurring costs"
echo "🔍 For detailed cost analysis, check AWS Cost Explorer in the console"
