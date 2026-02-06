import * as cdk from 'aws-cdk-lib';
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront';
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment';
import { Construct } from 'constructs';
import * as path from 'path';

export interface CloudFrontStackProps extends cdk.StackProps {
  envName?: string;
  webAclArn: string;
  originDomainName?: string;
}

export class CloudFrontStack extends cdk.Stack {
  public readonly distribution: cloudfront.Distribution;
  public readonly distributionDomainName: string;

  constructor(scope: Construct, id: string, props: CloudFrontStackProps) {
    super(scope, id, props);

    const envName = props.envName || 'demo';

    const originBucket = new s3.Bucket(this, 'OriginBucket', {
      bucketName: `${envName}-waf-demo-origin-${this.account}-${this.region}`,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
    });

    let defaultOrigin: cloudfront.IOrigin;

    if (props.originDomainName) {
      defaultOrigin = new origins.HttpOrigin(props.originDomainName, {
        protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
        httpPort: 80,
        originId: 'JuiceShopOrigin',
      });
    } else {
      const oai = new cloudfront.OriginAccessIdentity(this, 'OAI', {
        comment: `OAI for ${envName} WAF demo`,
      });
      originBucket.grantRead(oai);
      
      defaultOrigin = new origins.S3Origin(originBucket, {
        originAccessIdentity: oai,
        originId: 'S3Origin',
      });
    }

    this.distribution = new cloudfront.Distribution(this, 'Distribution', {
      defaultBehavior: {
        origin: defaultOrigin,
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
        cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD,
        cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED,
        originRequestPolicy: cloudfront.OriginRequestPolicy.ALL_VIEWER,
      },
      webAclId: props.webAclArn,
      defaultRootObject: 'index.html',
      errorResponses: [
        {
          httpStatus: 403,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.seconds(0),
        },
        {
          httpStatus: 404,
          responseHttpStatus: 200,
          responsePagePath: '/index.html',
          ttl: cdk.Duration.seconds(0),
        },
      ],
      comment: `${envName} WAF Bot Analysis Demo Distribution`,
      priceClass: cloudfront.PriceClass.PRICE_CLASS_100,
    });

    this.distributionDomainName = this.distribution.distributionDomainName;

    if (!props.originDomainName) {
      new s3deploy.BucketDeployment(this, 'DeployWebsite', {
        sources: [s3deploy.Source.asset(path.join(__dirname, '../static'))],
        destinationBucket: originBucket,
        distribution: this.distribution,
        distributionPaths: ['/*'],
      });
    }

    new cdk.CfnOutput(this, 'DistributionDomainName', {
      value: this.distributionDomainName,
      description: 'CloudFront Distribution Domain Name',
      exportName: `${envName}-cf-domain`,
    });

    new cdk.CfnOutput(this, 'DistributionId', {
      value: this.distribution.distributionId,
      description: 'CloudFront Distribution ID',
      exportName: `${envName}-cf-distribution-id`,
    });

    new cdk.CfnOutput(this, 'TestUrl', {
      value: `https://${this.distributionDomainName}`,
      description: 'Test URL for bot simulation',
      exportName: `${envName}-test-url`,
    });
  }
}
