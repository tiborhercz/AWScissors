import json
from urllib.request import Request, urlopen
import os

slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
account_name_list = os.environ.get('ACCOUNT_NAME_LIST')


def create_account_name_map():
    account_name_map = {}
    for account_name in account_name_list.split(","):
        account_id, name = account_name.split("=")
        account_name_map[account_id] = name
    return account_name_map


account_id_name_map = create_account_name_map()


def slack_notify_new_order(msg: str):
    message = {
        "text": msg
    }
    req = Request(slack_webhook_url, json.dumps(message).encode('utf-8'))
    req.add_header('Content-Type', 'application/json')
    response = urlopen(req)
    response.read()


def generate_cloudtrail_url(region: str, event_id: str) -> str:
    return (
        f"https://{region}.console.aws.amazon.com/cloudtrailv2/home?region={region}#/events/{event_id}"
    )


def from_console_text(event_detail: dict) -> str:
    session_from_console_text = "through API"
    if event_detail.get('sessionCredentialFromConsole') == "true":
        session_from_console_text = "through Management Console"
    return session_from_console_text


def get_account_name(account_id: str) -> str:
    if account_id_name_map.get(account_id) is None:
        return ''
    return f"{account_id_name_map.get(account_id)}/"


def lambda_handler(event, context):
    print(event)
    event_details = event.get("detail", {})
    output_message = f"✂️ `{event_details['userIdentity']['arn']}` performed a `{event_details['eventName']}` on `{event_details['eventSource']}` " \
                     f"in `{event_details['awsRegion']}` of account {get_account_name(event_details['userIdentity']['accountId'])}`{event_details['userIdentity']['accountId']}` " \
                     f"{from_console_text(event_details)}. \n" \
                     f"See <{generate_cloudtrail_url(event_details['awsRegion'], event_details['eventID'])}|CloudTrail Event> details"
    slack_notify_new_order(
        output_message
    )
