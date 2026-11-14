# hejo 문 (TASK-02)

Hermes 플랫폼 플러그인. 시설 코드는 이 폴더, 프레임 계약 원본은
[hejo-wire-v1.json](../schemas/hejo-wire-v1.json), 권한·기록장 계약은
[승인 설계](../docs/changes/HEJO-FOUNDATION-20261114/design.md)를 따른다.
운영 설치는 후속 TASK에서 한다.

Hermes Python 환경에서 저장소를 현재 폴더로 두고 실행:

```sh
python -m gate.cli pair
python -m gate.cli devices
python -m gate.cli revoke DEVICE_ID
python -m gate.cli status
python -m pytest gate/tests tests/acceptance/test_gate_foundation.py -q
```

`HERMES_HOME`은 Hermes의 홈 해석을 따른다. `pair`는 일회용 코드만 터미널에 출력한다.
`status`는 저장된 기기 개수와 취소 여부 요약이며 리스너 생존을 보증하지 않는다.
파일은 홈의 `hejo/`에 잠금·원자적 교체로 저장한다. 인증 자료 원문은 저장·로깅하지 않는다.

기본 프로필만 리스너를 연다. `extra.listen`, `extra.port`, `extra.allowed_users`를 읽으며
허용 사용자는 플러그인 YAML 브리지를 통해 Hermes 권한 검사로 전달한다.
보조 프로필은 재시도 불가 실패로 비활성화한다.

team-kit 확장은 어댑터의 `send(..., metadata=...)`,
`edit_message(..., *, finalize=False, metadata=None)`,
`await set_reply_state(msg_id, state)`, `register_click_handler("reply", handler)`만 사용한다.
`set_reply_state`는 fsync 완료 뒤 반환하고 기록 실패에는 `HejoJournalError`를 던진다.
버튼은 기록장 내부 메타에서 복원하며 전송 프레임에는 내부 메타를 넣지 않는다.

첨부 HTTP, 직원 사진 HTTP, Hermes 기본 버튼과 보조 프로필 배달은 TASK-03b 범위다.
이 단계는 해당 경로를 열지 않는다. 수신 첨부 id는 오류로 거부한다.
