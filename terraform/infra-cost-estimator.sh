#!/bin/bash

terraform init
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > plan.json

infracost breakdown --path=plan.json

