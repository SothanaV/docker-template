import base64
import json

user = input("user : ")
password = input("pass : ")

data = {
    'auths': {
        'registry.gitlab.com': {
            'username': user, 
            'password': password,
            'username_b64': base64.b64encode(user.encode()).decode(),
            'password_b64': base64.b64encode(password.encode()).decode(),
            'auth': base64.b64encode(f"{user}:{password}".encode()).decode()
        }
    }
}

print(f"\n\n {'='*5} DATA {'='*5} \n\n")
print(json.dumps(data, indent=3))
print(f"\n{base64.b64encode(json.dumps(data).encode()).decode()}")