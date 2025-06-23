import os
import json

os.system("docker ps -a --format json > tmp.json")

with open('tmp.json', 'r') as f:
    # print(len())
    data = [json.loads(elm) for elm in f.readlines()]
accept_ids = []
for container in data:
    print(f"id:\t{container.get('ID')} image:\t{container.get('Image')} name:\t{container.get('Names')}")
    status = input("Delete ? y/n/s : ")
    if status == 'y':
        accept_ids.append({
            'id': container.get('ID'),
            'name': container.get('Names')
        })
    elif status == 's':
        break
print(f"list delete container : {json.dumps(accept_ids, indent=2)}")
status = input("Delete ? y/n : ")
if status == 'y':
    os.system(f"docker rm {' '.join([elm.get('id') for elm in accept_ids])}")