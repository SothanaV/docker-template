import os
import threading
from ollama import Client

client = Client(host=os.environ.get('OLLAMA_URI', 'http://ollama:11434'))

def pull_image(model_name):
    res = client.pull(model=model_name)
    print(f"{model_name} => {res}")
        

models = os.environ.get('MODEL_NAMES', "").split(',')

threads = []
for model_name in models:
    th = threading.Thread(target=pull_image, args=(model_name,))
    th.start()
    threads.append(th)

for thread in threads:
    thread.join()
