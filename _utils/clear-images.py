import os
import json

os.system("docker images --format json > tmp.json")

with open('tmp.json', 'r') as f:
    # print(len())
    data = [json.loads(elm) for elm in f.readlines()]
accept_ids = []
for image in data:
    print(f"id:\t{image.get('ID')} image:\t{image.get('Repository')} name:\t{image.get('Size')}")
    status = input("Delete ? y/n/s : ")
    if status == 'y':
        accept_ids.append({
            'id': image.get('ID'),
            'name': image.get('Repository')
        })
    elif status == 's':
        break
print(f"list delete image : {json.dumps(accept_ids, indent=2)}")
status = input("Delete ? y/n : ")
if status == 'y':
    os.system(f"docker rmi {' '.join([elm.get('id') for elm in accept_ids])}")