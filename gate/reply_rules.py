"""Presentation and timing shared by live replies and journal projections."""

UNDO_SECONDS = 5
UNDO_GRACE_SECONDS = 6
RETRACT_TEXT = (
    "[답 취소] 사장이 방금 이 질문에 보낸 답을 취소했어요. 그 답으로 시작한 일은 멈춰 주세요. "
    "이미 처리된 일은 되돌리지 말고, 무엇이 처리됐는지 사장에게 알려 주세요."
)
STANDARD = ("승인", "거절", "의견", "확인")
LABELS = {
    "승인": ("approve", "circle"),
    "거절": ("reject", "xmark"),
    "의견": ("comment", "pencil"),
    "확인": ("confirm", "checkmark"),
    "메모": ("other", "note.text"),
    "메모+노션": ("other", "doc.on.doc"),
    "되돌리기": ("undo", "arrow.uturn.backward"),
    "제작해": ("approve", "play"),
    "다운": ("approve", "arrow.down"),
    "수정": ("other", "pencil"),
    "취소": ("reject", "xmark"),
    "종결": ("reject", "xmark"),
}
RESULTS = {"approve": "승인함", "reject": "거절함", "confirm": "확인함", "comment": "의견 보냄"}


def has_native_buttons(message):
    return any(button.get("kind") in ("approval", "clarify", "slash") for button in message.get("buttons") or ())


def word(label):
    if label.startswith(":") and ":" in label[1:]:
        return label.split(":", 2)[2].strip()
    return label


def styled(buttons):
    memo = any(word(b["label"]) in ("메모", "메모+노션") for b in buttons)
    result = []
    for index, button in enumerate(buttons):
        label = word(button["label"])
        role, icon = LABELS.get(label, ("other", None))
        result.append(
            dict(
                button,
                role=role,
                primary=index == 0,
                repeat=role == "undo",
                accent="green" if label == "승인" and not memo else "blue",
                **({"icon": icon} if icon else {}),
            )
        )
    return result


def standard():
    return styled(
        [
            dict(
                id="std:" + LABELS[label][0],
                label=label,
                kind="reply",
                style="primary" if index == 0 else "default",
            )
            for index, label in enumerate(STANDARD)
        ]
    )
