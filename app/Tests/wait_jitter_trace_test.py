#!/usr/bin/env python3
"""AT-WJ-08b positive and negative controls for the trace verdict."""

import unittest

from wait_jitter_trace import assess


def layout(event, delta, *, above=0, origin=300, follow=None):
    row = dict(wait_jitter="thread_layout", view=1, event=event, signature_changed=True,
               height_before=1000, height_after=1000 + delta, viewport_after=300,
               origin_before=origin, above_delta=above, cards=[])
    if follow is not None:
        row["follow_distance"] = follow
    return row


def move(event, start, delta, *, reserved=None, reason="keep", time=1):
    return dict(wait_jitter="thread_move", view=1, event=event,
                reserved_event=event if reserved is None else reserved, before=start,
                after=start + delta, reason=reason, monotonic=time, wall_ms=time * 1000)


def sidebar(event, *, delta=0, inserted=0, layout_call="none"):
    old = [dict(id=7, height=40)]
    new = ([dict(id=6, height=inserted)] if inserted else []) + old
    return dict(wait_jitter="sidebar", view=2, event=event, update=event,
                signature_changed=bool(inserted), layout=layout_call, origin_before=0,
                origin_after=0, geometry_before=old, geometry_after=new,
                rows_before=[dict(id=7, y=100)], rows_after=[dict(id=7, y=100 + delta)])


class WaitJitterControls(unittest.TestCase):
    def test_at_wj_08b(self):
        cases = {
            "ㄱ": ("reversals", [layout(1, 0), move(1, 300, 22), move(1, 322, -22, time=2)]),
            "ㄴ": ("late_moves", [layout(2, 22), move(2, 300, 22, reserved=1)]),
            "ㄷ": ("unchanged_sidebar_layouts", [sidebar(1, layout_call="row_heights")]),
            "ㄹ": ("unexplained_events", [
                layout(1, 34, above=34), move(1, 300, 34),
                layout(2, 2, origin=334), move(2, 334, -34, time=2)]),
            "ㅁ": ("unexplained_events", [layout(1, 1), move(1, 300, 22)]),
            "ㅂ": ("sidebar_moves", [sidebar(1, delta=15), sidebar(2, delta=-15)]),
            "ㅅ": (None, [layout(1, 34, above=34), move(1, 300, 34),
                          layout(2, -34, above=-34, origin=334), move(2, 334, -34, time=2)]),
            "ㅇ": (None, [layout(1, 40, origin=600, follow=140),
                          move(1, 600, 95, reason="follow"), move(1, 695, 45, reason="follow", time=2)]),
            "ㅈ": (None, [layout(1, 300), move(1, 300, 300)]),
            "ㅊ": (None, [sidebar(1, delta=-34, inserted=34, layout_call="sidebar_motion")]),
            "ㅋ": (None, [layout(1, -34, origin=600, follow=66), move(1, 600, 30, reason="follow")]),
            "ㅌ": ("unexplained_events", [
                layout(1, -34, origin=600, follow=66), move(1, 600, -20, reason="follow")]),
            "ㅍ": ("unexplained_events", [
                layout(1, -34, origin=600, follow=66), move(1, 600, 90, reason="follow")]),
        }
        for name, (metric, rows) in cases.items():
            with self.subTest(name=name):
                counts = assess(rows)["counts"]
                if metric:
                    self.assertGreaterEqual(counts[metric], 1)
                else:
                    self.assertEqual(set(counts.values()), {0})


if __name__ == "__main__":
    unittest.main()
