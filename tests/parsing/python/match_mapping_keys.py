def classify(event):
    match event:
        case {Color.RED: found, "a": a, 1: one}:
            return found
        case {"a": a, "b": b}:
            return a
