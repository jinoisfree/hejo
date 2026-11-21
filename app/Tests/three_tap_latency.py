"""Summarize opt-in frame-injection traces; never infer physical trackpad latency."""
import argparse
import json
from pathlib import Path
from statistics import median

SEGMENTS = {
    "frame_to_recognized": ("frame", "recognized"),
    "recognized_to_main": ("recognized", "main"),
    "main_to_expanded": ("main", "expanded"),
    "expanded_to_movement": ("expanded", "movement"),
    "movement_to_finished": ("movement", "finished"),
    "frame_to_movement": ("frame", "movement"),
    "capture": ("capture_start", "capture_end"),
    "expansion_callbacks": ("callbacks_start", "callbacks_end"),
    "timer_to_movement": ("timer_start", "movement"),
}


def summarize(path):
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    assert len(rows) == 20, "exactly twenty complete samples required"
    result = {}
    for opening, direction in ((1, "open"), (0, "close")):
        group = [row for row in rows if row["opening"] == opening]
        assert len(group) == 10, "ten samples per direction required"
        values = {}
        for name, (start, end) in SEGMENTS.items():
            samples = [1000 * (row[end] - row[start]) for row in group]
            assert min(samples) >= 0, "timestamps must be ordered"
            values[name] = {"median_ms": round(median(samples), 3), "max_ms": round(max(samples), 3)}
        result[direction] = {"count": len(group), "segments": values}
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("--after", type=Path)
    args = parser.parse_args()
    result = {"evidence": "injected_frames", "before": summarize(args.before)}
    if args.after:
        result["after"] = summarize(args.after)
        result["acceptance"] = {
            direction: result["after"][direction]["segments"]["frame_to_movement"]["median_ms"]
            < result["before"][direction]["segments"]["frame_to_movement"]["median_ms"]
            and result["after"][direction]["segments"]["frame_to_movement"]["median_ms"] <= 100
            for direction in ("open", "close")
        }
    print(json.dumps(result, indent=2))
    if args.after and not all(result["acceptance"].values()):
        raise SystemExit(1)
