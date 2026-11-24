def f(x):
    # ERROR:
    match x:
        case {1: n, "a": a}:
            print(a)

def g(x):
    match x:
        case {1: n, "b": b}:
            print(b)
