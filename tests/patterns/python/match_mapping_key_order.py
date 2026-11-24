def f(x):
    # ERROR:
    match x:
        case {1: n, "a": a}:
            print(a)

def g(x):
    # ERROR:
    match x:
        case {"a": a, 1: n}:
            print(a)

def h(x):
    match x:
        case {"a": a, 2: n}:
            print(a)
