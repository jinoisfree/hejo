"""Small deterministic journal input; expected output comes from the frozen app."""
import uuid


def identifier(value):
    return str(uuid.UUID(int=value))


def rows():
    result = []
    def add(kind, **values):
        result.append(dict(v=1, type=kind, seq=len(result) + 1, **values))
    def message(number, text, employee="alpha", thread=None, **values):
        fields = dict(msg_id=identifier(number), employee=employee,
            thread=identifier(thread or number), role="employee", text=text,
            files=[], buttons=[], reply_state=None, ts="2026-01-01T00:00:00Z")
        fields.update(values); add("message", **fields)
    for number in (101, 102):
        add("room", room=dict(id=identifier(number), title=f"Fixture room {number}",
            members=["alpha", "beta"], lead="alpha", description="", picture=None, archived=False))
    message(1, "오래된 질문 승인해 줘", reply_state="asked", ts="2020-01-01T00:00:00Z")
    message(2, "한글 검색 Alpha", employee="beta")
    message(3, "생각 중...", thread=1)
    add("edit", msg_id=identifier(3), text="완료한 답", final=True)
    message(4, "그룹 질문", room=identifier(101), reply_state="asked")
    message(5, "승인", room=identifier(101), thread=4, role="owner")
    message(6, "처리 완료", room=identifier(101), thread=4)
    add("state", msg_id=identifier(4), reply_state="closed")
    message(7, "닫힐 글", employee="gamma")
    add("delete", msg_id=identifier(7))
    message(8, "", employee="beta", files=[dict(file_id=identifier(800), name="fixture.txt", mime="text/plain", size=0)])
    message(9, "- [ ] 확인 항목", employee="gamma")
    message(10, "삭제될 방 글", room=identifier(102))
    add("room_delete", room=identifier(102))
    message(11, "아주 오래된 스레드의 새 답변", thread=1)
    return result
