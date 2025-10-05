import random as rd
import string
import re
import os
from pathlib import Path

kind = {
    '1': string.ascii_letters,
    '2': string.ascii_letters + string.digits,
    '3': re.sub("""\"|\'""",'',(string.ascii_letters + string.digits + string.punctuation))
}
print(f"\t{'='*5} RANDOM PASSWORD {'='*5}")
for k, v in kind.items():
    print(f" {k}) {v}")

pass_type = input("Please select (1-3) for random type : ")
length = input("Please input length (1-255) : ")
name = input("Please input name : ")
output = ''.join(rd.choices(kind.get(pass_type), k=int(length)))

output_path = Path.home() / 'Desktop/random-pass.txt'

if not os.path.exists(output_path):
    with open(output_path, 'a') as f:
        f.write(f'name\tpass\n')

with open(output_path, 'a') as f:
    f.write(f"{name}\t{output}\n")

print(f"\t {name} PASSWORD : {output}")