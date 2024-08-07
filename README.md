# AWScissors ✂️

AWScissors is created to notify users when manual changes are being made by a users without using the Infrastructure as Code and cut off their fingers for doing so :)

When adopting Infrastructure as Code you want to prevent drift caused by users changing the infrastructure outside of the Infrastructure as Code repo.
To get notified of any changes made by users you can deploy AWScissors into your AWS accounts.

AWScissors uses the AWS default eventBridge to trigger a Lambda when an users performs non readonly API calls.

## CloudFormation parameters

### EventRuleWildcardArn 

The ARN of role that you want to get notified on when a NON readonly actions is performed. 

Example: 
```
arn:aws:sts::*:assumed-role/AWSReservedSSO_*
```

### AccountNameList 

List of accountIds and names separated by a comma. 

Example: 
```
12345678911=account1,12345678912=account2,12345678913=account3
```

### SlackwebhookUrl 

The Slack webhook URL to send the notifications to. 

Example: `https://hooks.slack.com/services/AWERH4ABCDEFG/AWERH4ABCDEFG/AWERH4ABCDEFGAWERH4ABCDEFG`

## AWS EventBridge Eventpatterns

In all the event patterns we only look for NON readOnly events, meaning anything that is changed in the AWS environment.
Next to that we have a separate event pattern per user type.

Currently it supports:
- Root user
- IAM user
- SSO user

It uses the following event patterns:

```
{
  "detail" : {
    "readOnly" : [false],
    "userIdentity" : {
      "type" : ["Root"]
    }
  }
}
```

```
{
  "detail" : {
    "readOnly" : [false],
    "userIdentity" : {
      "type" : ["IAMUser"]
    }
  }
}
```

```
{
  "detail" : {
    "readOnly" : [false],
    "userIdentity" : {
      "type" : ["AssumedRole"],
      "arn" : [
        {
          "wildcard" : "arn:aws:sts::*:assumed-role/AWSReservedSSO_*"
        }
      ]
    }
  }
}
```
