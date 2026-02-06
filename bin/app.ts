#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { WafStack } from '../lib/waf-stack';
import { CloudFrontStack } from '../lib/cloudfront-stack';

const app = new cdk.App();

const envName = app.node.tryGetContext('envName') || 'demo';
const originDomainName = app.node.tryGetContext('originDomainName'); // Optional: JuiceShop ALB domain

// WAF Stack MUST be in us-east-1 for CloudFront
const wafStack = new WafStack(app, 'WafBotControlStack', {
  envName,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: 'us-east-1', // Required for CloudFront WebACL
  },
  crossRegionReferences: true,
});

// CloudFront Stack can be in any region, but we keep it in us-east-1 for simplicity
const cloudFrontStack = new CloudFrontStack(app, 'CloudFrontWafDemoStack', {
  envName,
  webAclArn: wafStack.webAclArn,
  originDomainName,
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: 'us-east-1',
  },
  crossRegionReferences: true,
});

cloudFrontStack.addDependency(wafStack);

app.synth();
