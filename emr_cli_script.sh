#! /bin/bash

# Before you start:
# http://docs.aws.amazon.com/cli/latest/userguide/installing.html
# pip install awscli
# aws configure

REGION="us-east-1"
BUCKET="emr-example-$REGION-$(date +%Y%m%d-%H%M)"

#Hive sample data and query
SAMPLES="s3://$REGION.elasticmapreduce.samples"
QUERY="s3://$REGION.elasticmapreduce.samples/cloudfront/code/Hive_CloudFront.q"

echo "### Parameters"
echo -e "$REGION"
echo -e "$SAMPLES"
echo -e "$QUERY"
echo -e "$BUCKET"


echo "### Create target Bucket"
# create S3 bucket
# create S3 folders {output, logs}

aws s3 mb "s3://$BUCKET"
aws s3 ls

echo "### Create Cluster"
# create cluster
# add step
aws emr create-cluster \
  --name "EMR Example" \
  --release-label emr-4.5.0 \
  --no-enable-debugging \
  --no-termination-protected \
  --use-default-roles \
  --instance-groups \
  InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m3.xlarge \
  InstanceGroupType=CORE,InstanceCount=2,InstanceType=m3.xlarge \
  --steps Type=STREAMING,Name='Streaming Program',ActionOnFailure=CONTINUE,Args=[-files,s3://elasticmapreduce/samples/wordcount/wordSplitter.py,-mapper,wordSplitter.py,-reducer,aggregate,-input,s3://elasticmapreduce/samples/wordcount/input,-output,s3://$BUCKET/wordcount/output] \
  --auto-terminate \
  --log-uri "s3://$BUCKET/wordcount/logs"

aws emr list-clusters

# TODO wait for cluster to finish...
S3_TARGET="s3://$BUCKET/wordcount/output/"
CLUSTER_FINISHED="$(aws s3 ls $S3_TARGET )"

while [ -z "$CLUSTER_FINISHED" ]; do
  echo "$(date +%Y-%m-%d %H:%M.%s) Cluster not finished yet. Waiting..."
  sleep 60
  CLUSTER_FINISHED="$(aws s3 ls $S3_TARGET )"
done

echo "### Load results"
# extract results
mkdir -pv output
aws s3 sync "s3://$BUCKET/wordcount/output" ./output
ls -laFGh output/

echo "### Cleaning up"
# aws s3 rb "s3://$BUCKET" --force
