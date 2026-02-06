import * as cdk from 'aws-cdk-lib';
import * as wafv2 from 'aws-cdk-lib/aws-wafv2';
import * as logs from 'aws-cdk-lib/aws-logs';
import { Construct } from 'constructs';

export interface WafStackProps extends cdk.StackProps {
  envName?: string;
}

export class WafStack extends cdk.Stack {
  public readonly webAclArn: string;
  public readonly logGroup: logs.LogGroup;

  constructor(scope: Construct, id: string, props?: WafStackProps) {
    super(scope, id, props);

    const envName = props?.envName || 'demo';

    this.logGroup = new logs.LogGroup(this, 'WafLogGroup', {
      logGroupName: `aws-waf-logs-${envName}-bot-analysis`,
      retention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    const webAcl = new wafv2.CfnWebACL(this, 'WebAcl', {
      name: `${envName}-bot-control-webacl`,
      scope: 'CLOUDFRONT',
      defaultAction: { allow: {} },
      visibilityConfig: {
        sampledRequestsEnabled: true,
        cloudWatchMetricsEnabled: true,
        metricName: `${envName}WebAclMetric`,
      },
      rules: [
        {
          name: 'AWSManagedRulesBotControlRuleSet',
          priority: 1,
          statement: {
            managedRuleGroupStatement: {
              vendorName: 'AWS',
              name: 'AWSManagedRulesBotControlRuleSet',
            },
          },
          overrideAction: { count: {} },
          visibilityConfig: {
            sampledRequestsEnabled: true,
            cloudWatchMetricsEnabled: true,
            metricName: `${envName}BotControlMetric`,
          },
        },
        {
          name: 'RateLimitRule',
          priority: 2,
          statement: {
            rateBasedStatement: {
              limit: 2000,
              aggregateKeyType: 'IP',
            },
          },
          action: { block: {} },
          visibilityConfig: {
            sampledRequestsEnabled: true,
            cloudWatchMetricsEnabled: true,
            metricName: `${envName}RateLimitMetric`,
          },
        },
      ],
    });

    this.webAclArn = webAcl.attrArn;

    const loggingConfig = new wafv2.CfnLoggingConfiguration(this, 'WafLoggingConfig', {
      resourceArn: webAcl.attrArn,
      logDestinationConfigs: [
        cdk.Stack.of(this).formatArn({
          service: 'logs',
          resource: 'log-group',
          resourceName: this.logGroup.logGroupName,
          arnFormat: cdk.ArnFormat.COLON_RESOURCE_NAME,
        }),
      ],
    });

    loggingConfig.addDependency(webAcl);

    new cdk.CfnOutput(this, 'WebAclArnOutput', {
      value: this.webAclArn,
      description: 'WAF WebACL ARN for CloudFront association',
      exportName: `${envName}-webacl-arn`,
    });

    new cdk.CfnOutput(this, 'LogGroupNameOutput', {
      value: this.logGroup.logGroupName,
      description: 'CloudWatch Log Group for WAF logs',
      exportName: `${envName}-waf-log-group`,
    });
  }
}
