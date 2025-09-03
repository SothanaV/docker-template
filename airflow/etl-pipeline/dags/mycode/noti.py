import random

def ran_err():
    if random.randint(0, 1) == 1:
        raise Exception('Error dag')
    print("Pass !")