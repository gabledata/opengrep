def f(x):
    # ERROR:
    match x:
        case {"b": b, "a": a, **rest}:
            print(rest)

def g(x):
    match x:
        case {"b": b, "a": a}:
            print(a)
