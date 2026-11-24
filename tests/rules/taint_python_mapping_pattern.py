def string_key_binds_its_value():
    m = {"a": taint_source(), "b": "safe"}
    match m:
        case {"a": a, "b": b}:
            # ruleid: taint-python-mapping-pattern
            sink(a)
            # ok: taint-python-mapping-pattern
            sink(b)


def string_key_beside_a_numeric_key():
    m = {1: "safe", "a": taint_source()}
    match m:
        case {1: n, "a": a}:
            # ruleid: taint-python-mapping-pattern
            sink(a)


def numeric_key_binds_its_value():
    m = {1: taint_source()}
    match m:
        case {1: one}:
            # todoruleid: taint-python-mapping-pattern
            sink(one)
