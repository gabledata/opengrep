def f(x):
    # ERROR:
    match x:
        case {"a": a, Color.RED: r}:
            print(r)

def g(x):
    match x:
        case {"a": a, Color.BLUE: b}:
            print(b)
