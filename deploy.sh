#!/bin/bash
# Deploy shreshthagarwal.com to AWS S3 + CloudFront
# Run: chmod +x deploy.sh && ./deploy.sh

set -e

BUCKET_NAME="shreshthagarwal.com"
REGION="ap-south-1"

echo "==> Creating S3 bucket..."
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" \
  2>/dev/null || echo "Bucket may already exist, continuing..."

echo "==> Configuring bucket for static website hosting..."
aws s3 website "s3://$BUCKET_NAME" \
  --index-document index.html \
  --error-document 404.html

echo "==> Setting bucket policy for public read..."
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"PublicReadGetObject\",
    \"Effect\": \"Allow\",
    \"Principal\": \"*\",
    \"Action\": \"s3:GetObject\",
    \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
  }]
}"

echo "==> Blocking public access (will use CloudFront OAC instead)..."
# Note: If using CloudFront OAC, uncomment below and remove the public policy above
# aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
#   --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Uploading files..."
aws s3 sync . "s3://$BUCKET_NAME" \
  --exclude ".git/*" \
  --exclude ".gitignore" \
  --exclude "deploy.sh" \
  --exclude ".DS_Store" \
  --exclude "*.md" \
  --exclude "Shreshth-Agarwal-CV*" \
  --cache-control "public, max-age=3600" \
  --delete

# Set long cache for static assets
aws s3 cp "s3://$BUCKET_NAME/favicon.svg" "s3://$BUCKET_NAME/favicon.svg" \
  --metadata-directive REPLACE \
  --cache-control "public, max-age=31536000, immutable" \
  --content-type "image/svg+xml"

# Set correct content types
aws s3 cp "s3://$BUCKET_NAME/sitemap.xml" "s3://$BUCKET_NAME/sitemap.xml" \
  --metadata-directive REPLACE \
  --cache-control "public, max-age=86400" \
  --content-type "application/xml"

aws s3 cp "s3://$BUCKET_NAME/robots.txt" "s3://$BUCKET_NAME/robots.txt" \
  --metadata-directive REPLACE \
  --cache-control "public, max-age=86400" \
  --content-type "text/plain"

echo "==> Done! Site uploaded to S3."
echo ""
echo "Next steps:"
echo "1. Create CloudFront distribution pointing to: $BUCKET_NAME.s3-website.$REGION.amazonaws.com"
echo "2. Request ACM certificate for shreshthagarwal.com (must be in us-east-1 for CloudFront)"
echo "3. Point domain DNS to CloudFront distribution"
echo "4. Add response headers policy in CloudFront with security headers"
echo ""
echo "S3 website URL: http://$BUCKET_NAME.s3-website.$REGION.amazonaws.com"
