"""Strict bounded JSON data shared by HTTP ingress and immutable storage."""

import json
import math


def strict_object(pairs):
    result = {}
    for key, value in pairs:
        key.encode("utf-8")
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def reject_constant(_value):
    raise ValueError("Nonfinite JSON value")


def parse_json(body, *, maximum_nodes=1200000):
    parsed = json.loads(body, object_pairs_hook=strict_object, parse_constant=reject_constant)
    # Iterators keep traversal memory proportional to depth rather than the
    # number of siblings in a maximum replay or stored list.
    pending = [(iter((parsed,)), 0)]
    scheduled = 1
    while pending:
        values, depth = pending[-1]
        try:
            value = next(values)
        except StopIteration:
            pending.pop()
            continue
        if depth > 32:
            raise ValueError("JSON nesting limit")
        if isinstance(value, (dict, list)):
            scheduled += len(value)
            if scheduled > maximum_nodes:
                raise ValueError("JSON node limit")
            children = value.values() if isinstance(value, dict) else value
            pending.append((iter(children), depth + 1))
        elif isinstance(value, float) and not math.isfinite(value):
            # parse_constant alone does not catch exponent overflow (1e400).
            raise ValueError("Nonfinite JSON number")
        elif isinstance(value, str):
            value.encode("utf-8")
    return parsed
