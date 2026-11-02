# Deploy SecureGate: Supabase + AWS

SecureGate is hosted on AWS while Supabase remains the PostgreSQL database.

## AWS architecture

- **CloudFront + private S3** serve the web application.
- **API Gateway + Lambda** run the protected `/api/*` routes.
- **AWS Secrets Manager** provides the Supabase connection string and first-admin details at deployment time.
- **Supabase** keeps the existing database and SQL migrations.

The CloudFront distribution forwards only the required API cookies and CSRF headers. The S3 bucket is private and can only be read through CloudFront Origin Access Control (OAC).

## One-time setup

1. In Supabase SQL Editor, run `supabase/migrations/20260713170000_securegate_schema.sql` for a new database. For an existing database, also run `supabase/migrations/20260715140000_outward_pod_tokens.sql`.
2. Install Node.js 20, the AWS CLI, and the AWS SAM CLI. Run `aws configure` with an AWS user/role that can deploy CloudFormation, Lambda, API Gateway, S3, CloudFront, IAM, and Secrets Manager resources. Use the same AWS Region for the secret and stack (for example, `ap-south-1`).
3. In **AWS Secrets Manager**, create an **Other type of secret** using the JSON structure in `aws/secret.example.json`. Use your real Supabase Transaction Pooler connection string and strong admin password. Do not upload that JSON file or commit real secret values.
4. This package is already configured for secret `supabase` with ARN `arn:aws:secretsmanager:ap-south-1:179923444852:secret:supabase-vxX7hO`.

## Deploy to AWS

From PowerShell in the project folder, run:

```powershell
& .\aws\deploy.ps1
```

The default stack is `securegate-prod` in `ap-south-1`. You may still override any value with `-StackName`, `-AppSecretArn`, or `-Region`.

The script builds the application, deploys the AWS stack, uploads `dist` to the private S3 bucket, invalidates CloudFront, and prints the CloudFront website URL. Open that URL to use SecureGate.

For an update, run the same command again. Your Supabase data is not moved or deleted.

## AWS Amplify Hosting

The repository includes `amplify.yml`. Commit it at the repository root and Amplify will install pnpm 9, build the site, and publish the `dist` directory.

If the Amplify app was created with an empty platform or build specification, apply the validated settings with AWS CLI from the project root:

```powershell
aws amplify update-app --cli-input-json file://aws/amplify-update-input.json --region ap-south-1
```

The included input is configured for app ID `d1n26u74la43b2` and static platform `WEB`.

Amplify Hosting publishes the frontend only. The protected API still has to be deployed with `aws/deploy.ps1`. If you use the Amplify URL instead of the CloudFront URL, add a **200 rewrite** under **Amplify > Hosting > Rewrites and redirects**. Use `aws/amplify-redirects.example.json`, replacing `YOUR_API_ID` with the API Gateway ID from the stack output. Keep the `/api/<*>` rule above any catch-all SPA rule.

## Custom domain

To use your own domain, request an ACM certificate in **us-east-1**, add it to the CloudFront distribution, and point your DNS record to the CloudFront domain. This is optional; the generated CloudFront URL works immediately.

