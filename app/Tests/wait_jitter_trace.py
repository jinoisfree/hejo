#!/usr/bin/env python3
"""Evaluate the five wait-jitter diagnostics from HEJO_THREE_TAP_TRACE JSON lines."""

import argparse
from bisect import bisect_right
from collections import defaultdict
import json

EPSILON = 0.5
METRICS = ("reversals", "late_moves", "unexplained_events", "unchanged_sidebar_layouts", "sidebar_moves")


def read_trace(path):
    with open(path, encoding="utf-8") as stream:
        for line in stream:
            row = json.loads(line)
            if "wait_jitter" in row:
                yield row


def reversals(moves):
    direction = 0
    extreme = moves[0]["before"] if moves else 0
    for row in moves:
        step = row["after"] - extreme
        if abs(step) <= EPSILON:
            continue
        sign = 1 if step > 0 else -1
        if direction and direction != sign:
            yield row["wall_ms"]
        direction, extreme = sign, row["after"]


def explained(layout, moves):
    if not moves:
        return True
    delta = sum(row["after"] - row["before"] for row in moves)
    if layout is None:
        return abs(delta) <= EPSILON
    before = layout["origin_before"]
    maximum = max(0, layout["height_after"] - layout["viewport_after"])
    total_height_change = layout["height_after"] - layout["height_before"]
    above = layout["above_delta"]
    if all(row["reason"] == "follow" for row in moves) and "follow_distance" in layout:
        target = layout["follow_distance"]
        return min(0, target) - EPSILON <= delta <= max(0, target) + EPSILON
    clamp = lambda y: min(maximum, max(0, y))
    if any(abs(delta - expected) <= EPSILON or abs(before + delta - clamp(before + expected)) <= EPSILON
           for expected in (0, above, total_height_change)):
        return True
    for card in layout["cards"]:
        if card["crosses_top"]:
            first = clamp(before + above) - before
            last = clamp(before + above + card["delta"]) - before
            if min(first, last) - EPSILON <= delta <= max(first, last) + EPSILON:
                return True
    return False


def offsets(geometry):
    top = 0
    result = {}
    for row in geometry:
        result[row["id"]] = top
        top += row["height"]
    return result


def unstable_sidebar_rows(row):
    before = {position["id"]: position["y"] for position in row["rows_before"]}
    after = {position["id"]: position["y"] for position in row["rows_after"]}
    old_top = offsets(row["geometry_before"])
    new_top = offsets(row["geometry_after"])
    scroll_delta = row["origin_after"] - row["origin_before"]
    for identifier in before.keys() & after.keys():
        expected = scroll_delta - (new_top[identifier] - old_top[identifier])
        if abs(after[identifier] - before[identifier] - expected) > EPSILON:
            yield identifier


def assess(rows):
    findings = {metric: [] for metric in METRICS}
    motions = defaultdict(list)
    layouts = {}
    inputs = defaultdict(list)
    sidebar_updates = defaultdict(list)

    for row in rows:
        kind = row["wait_jitter"]
        view = row["view"]
        if kind == "input":
            inputs[view].append(row["monotonic"])
        elif kind == "thread_layout" and row["signature_changed"]:
            layouts[(view, row["event"])] = row
        elif kind == "thread_move":
            motions[(view, row["event"])].append(row)
        elif kind == "sidebar":
            sidebar_updates[(view, row["update"])].append(row)

    for times in inputs.values():
        times.sort()
    for (view, event), moves in motions.items():
        times = inputs[view]
        automatic = []
        for row in sorted(moves, key=lambda item: item["monotonic"]):
            index = bisect_right(times, row["monotonic"]) - 1
            if index >= 0 and row["monotonic"] - times[index] <= 0.5:
                continue
            automatic.append(row)
            if row["reserved_event"] < event:
                findings["late_moves"].append((view, event, row["reserved_event"], row["wall_ms"]))
        findings["reversals"].extend((view, event, time) for time in reversals(automatic))
        if not explained(layouts.get((view, event)), automatic):
            findings["unexplained_events"].append((view, event))

    for (view, update), records in sidebar_updates.items():
        initial = records[0]
        if not initial["signature_changed"] and initial["layout"] != "none":
            findings["unchanged_sidebar_layouts"].append((view, initial["event"], update))
        # A transition legitimately passes through intermediate placements. Compare
        # the final placement with the geometry for the same update.
        final = records[-1]
        findings["sidebar_moves"].extend(
            (view, final["event"], update, identifier)
            for identifier in unstable_sidebar_rows(final)
        )

    return {"counts": {key: len(value) for key, value in findings.items()}, "failures": findings}



def verify_harness_records(rows):
    fields = {
        "thread_layout": {"event", "signature_changed", "cards", "height_before", "height_after",
                          "origin_before", "origin_after", "viewport_before", "viewport_after",
                          "end_gap", "above_delta"},
        "thread_move": {"event", "reason", "generation", "reserved_event", "before", "after"},
        "sidebar": {"event", "layout", "phase", "changed_rows", "rows_before", "rows_after", "geometry_before",
                    "geometry_after", "origin_before", "origin_after"},
        "input": {"input"},
    }
    kinds = {row["wait_jitter"] for row in rows}
    if kinds != fields.keys():
        raise ValueError("required wait-jitter record kinds are missing")
    events = defaultdict(int)
    counts = defaultdict(int)
    wheel_observed = False
    for row in rows:
        kind = row["wait_jitter"]
        if not fields[kind] | {"wall_ms", "monotonic", "view"} <= row.keys():
            raise ValueError(f"incomplete {kind} record")
        if kind == "input":
            wheel_observed |= row["input"] == "wheel"
        if kind == "thread_layout":
            view = row["view"]
            change = int(row["signature_changed"])
            if row["event"] != events[view] + change:
                raise ValueError("thread geometry signature and event index disagree")
            events[view] = row["event"]
            counts[view] += change
    if not wheel_observed or not any(total >= 13 for total in counts.values()):
        raise ValueError("streaming or wheel input is absent from the harness trace")
    if any("Fixture " in json.dumps(row) for row in rows):
        raise ValueError("fixture content entered the trace")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace")
    parser.add_argument("--harness", action="store_true", help="validate the AT-WJ-08 harness records")
    arguments = parser.parse_args()
    rows = list(read_trace(arguments.trace))
    if not rows:
        parser.error("no wait-jitter records")
    if arguments.harness:
        try:
            verify_harness_records(rows)
        except ValueError as error:
            parser.error(str(error))
    result = assess(rows)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return int(any(result["counts"].values()))


if __name__ == "__main__":
    raise SystemExit(main())
