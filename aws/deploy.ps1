param(
  [string]$StackName = 'securegate-prod',
  [string]$AppSecretArn = 'arn:aws:secretsmanager:ap-south-1:179923444852:secret:supabase-vxX7hO',
  [string]$Region = 'ap-south-1'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

foreach ($commandName in @('node', 'npm', 'aws', 'sam')) {
  if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
    throw "Required command '$commandName' was not found. Install Node.js 20, AWS CLI and AWS SAM CLI, then reopen PowerShell."
  }
}

Push-Location $root
try {
  $secretJson = aws secretsmanager get-secret-value --secret-id $AppSecretArn --region $Region --query SecretString --output text
  if ($LASTEXITCODE -ne 0) {
    throw "Could not read the configured Secrets Manager secret. Check AWS credentials, Region, ARN, and secretsmanager:GetSecretValue permission."
  }

  try {
    $secretValue = $secretJson | ConvertFrom-Json
  } catch {
    throw "The configured secret must contain a JSON object. Use the keys shown in aws/secret.example.json."
  }

  foreach ($requiredSecretKey in @('SUPABASE_DB_URL', 'BOOTSTRAP_ADMIN_USERNAME', 'BOOTSTRAP_ADMIN_PASSWORD', 'BOOTSTRAP_ADMIN_NAME')) {
    if ([string]::IsNullOrWhiteSpace([string]$secretValue.$requiredSecretKey)) {
      throw "Secrets Manager secret is missing required key '$requiredSecretKey'."
    }
  }
  Remove-Variable secretJson, secretValue

  node scripts/build.mjs
  sam build --template-file aws/template.yaml
  sam deploy --stack-name $StackName --region $Region --capabilities CAPABILITY_IAM --resolve-s3 --no-confirm-changeset --no-fail-on-empty-changeset --parameter-overrides "AppSecretArn=$AppSecretArn"
  $bucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='SiteBucketName'].OutputValue" --output text
  $distribution = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" --output text
  aws s3 sync dist "s3://$bucket" --delete --cache-control 'no-store, max-age=0'
  aws cloudfront create-invalidation --distribution-id $distribution --paths '/*' | Out-Null
  $websiteUrl = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='WebsiteUrl'].OutputValue" --output text
  $httpApiUrl = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='HttpApiUrl'].OutputValue" --output text
  Write-Output "CloudFront application URL: $websiteUrl"
  Write-Output "Amplify API rewrite target: $httpApiUrl/api/<*>"
} finally {
  Pop-Location
}

