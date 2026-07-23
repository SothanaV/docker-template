import os
import time
import redis
import boto3

REDIS_HOST = os.getenv('REDIS_HOST', 'redis')
MINIO_ENDPOINT = os.getenv('MINIO_ENDPOINT', 'minio:9000')

print("Starting Python Consumer... Waiting for services to initialize.")
time.sleep(10)

# Connect to Redis
redis_client = redis.Redis(host=REDIS_HOST, port=6379, decode_responses=True)

print("Listening for Debezium CDC events on Redis Streams...")

# The stream name is usually the topic prefix + schema + table
# E.g., if you have a table named "users", the stream is "cdc.public.users"
# We will listen to a specific stream. Update accordingly.
STREAM_KEY = os.getenv('STREAM_KEY', 'cdc.public.your_table_name')

# Start reading from the end of the stream ('$')
# If you want to read from the beginning, use '0-0' instead of '$'
last_id = '$'

while True:
    try:
        # Read from the stream, block for up to 5 seconds if empty
        messages = redis_client.xread({STREAM_KEY: last_id}, count=10, block=5000)
        
        if messages:
            for stream, events in messages:
                for event_id, event_data in events:
                    print(f"Received Event ID {event_id}: {event_data}")
                    
                    # Process your data and push to MinIO here...
                    
                    # Update last_id to fetch only new messages next loop
                    last_id = event_id
                    
    except redis.exceptions.ResponseError as e:
        # Handle case where the stream doesn't exist yet
        pass
    except Exception as e:
        print(f"Error: {e}")
        time.sleep(2)
