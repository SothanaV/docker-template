import os
import json
from notebook.auth import passwd

password = os.environ.get('JUPYTER_PASSWORD', 'password')
password_hash = passwd(password)

jupyter_config = {
    "NotebookApp": {
      "password": password_hash
    }
}


os.makedirs('/config/', exist_ok=True)
with open('/config/jupyter_notebook_config.json', 'w') as f:
    json.dump(fp=f, obj=jupyter_config)

print(f"""
      Init jupyter password sucess
      password is => {password}
      config : {json.dumps(jupyter_config, indent=2)}
""")