import requests
import time
import random

# Define the node names and test names
node_names = [
    "Bangalore, IN - Tata Teleservices", 
    "Los Angeles, US - Comcast", 
    "Chicago, US - AT&T", 
    "New York, US - Cogent", 
    "Miami, US - AT&T"
]

test_names = ["Homepage fast", "Homepage med", "Homepage slow", "Homepage variance"]

# URL for the webhook endpoint
webhook_url = "http://localhost:9090/webhook"

def generate_metrics(test_name):
    base_time = {
        "Homepage fast": random.randint(1000, 2000),
        "Homepage med": random.randint(2000, 4000),
        "Homepage slow": random.randint(4000, 6000),
        "Homepage variance": random.randint(500, 7000)
    }

    total_time = base_time[test_name]

    return {
        "TestDetails": {
            "TestName": test_name,
            "TypeId": "0",
            "MonitorTypeId": "18",
            "TestId": str(random.randint(1000000, 9999999)),
            "ReportWindow": str(random.randint(1000000000000000, 9999999999999999)),
            "NodeId": str(random.randint(1000, 2000)),
            "NodeName": random.choice(node_names),
            "Asn": str(random.randint(40000, 60000)),
            "DivisionId": str(random.randint(2000, 3000)),
            "ClientId": str(random.randint(800, 900))
        },
        "Summary": {
            "Timestamp": str(int(time.time() * 1000)),
            "TotalTime": str(total_time),
            "Connect": str(random.randint(10, 30)),
            "Dns": str(random.randint(20, 50)),
            "ContentLoad": str(random.randint(500, 8000)),
            "Load": str(random.randint(500, 1000)),
            "Redirect": str(random.randint(200, 500)),
            "Send": "0",
            "SSL": str(random.randint(10, 30)),
            "Wait": str(random.randint(500, 1000)),
            "Client": str(random.randint(100, 200)),
            "DocumentComplete": str(total_time - random.randint(0, total_time)),
            "Dom Loaded": "",
            "Time To Title": "",
            "RenderStart": str(total_time - random.randint(0, total_time)),
            "ResponseContent": str(random.randint(50000, 200000)),
            "ResponseHeaders": str(random.randint(2000, 3000)),
            "TotalContent": str(random.randint(1000000, 2000000)),
            "TotalHeaders": str(random.randint(50000, 60000)),
            "AnyError": "False",
            # Set to False 80% of the time, else True
            "ConnectionError": "False" if random.randint(0, 1) < 0.8 else "True",
            "DNSError": "False" if random.randint(0, 1) < 0.8 else "True",
            "LoadError": "False" if random.randint(0, 1) < 0.8 else "True",
            "TimeoutError": "False" if random.randint(0, 1) < 0.8 else "True",
            "TransactionError": "False" if random.randint(0, 1) < 0.8 else "True",
            "ErrorObjectsLoaded": "False" if random.randint(0, 1) < 0.8 else "True",
            "ImageContentType": str(random.randint(500000, 600000)),
            "ScriptContentType": str(random.randint(500000, 600000)),
            "HTMLContentType": str(random.randint(100000, 200000)),
            "CSSContentType": str(random.randint(200000, 300000)),
            "FontContentType": str(random.randint(100000, 200000)),
            "MediaContentType": "0",
            "XMLContentType": "0",
            "OtherContentType": "0",
            "ConnectionsCount": str(random.randint(10, 20)),
            "HostsCount": str(random.randint(20, 30)),
            "FailedRequestsCount": str(random.randint(1, 6)),
            "RequestsCount": str(random.randint(50, 70)),
            "RedirectionsCount": str(random.randint(0, 5)),
            "CachedCount": "0",
            "ImageCount": str(random.randint(10, 20)),
            "ScriptCount": str(random.randint(10, 30)),
            "HTMLCount": str(random.randint(1, 5)),
            "CSSCount": str(random.randint(1, 5)),
            "FontCount": str(random.randint(1, 5)),
            "XMLCount": "0",
            "MediaCount": "0",
            "ReceiveCount": "",
            "SendCount": "",
            "TracepointsCount": "0"
        }
    }

def main():
    while True:
        for test_name in test_names:
            payload = generate_metrics(test_name)
            response = requests.post(webhook_url, json=payload)
            print(f"Sent {test_name} metrics, Response Code: {response.status_code}")
            time.sleep(50)  # Sleep for 30 seconds between requests
        time.sleep(50)  # Sleep for 30 seconds between requests

if __name__ == "__main__":
    main()
