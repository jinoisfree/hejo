# HEJO-TIDY 수락 시험

- 판: 3판(계획 검증 1회차 R1-01~04, 2회차 R2-01 반영) · 상태: 명세 확정 / 코드 미작성 / 미실행 / 독립 검토: 계획 검증 3회차 APPROVED
- 가짜 값만 쓴다: 임시 폴더, 가짜 번들 ID(`invalid.example.other`), 가짜 홈, 멘션 `@acct`·`@a`·`@b`.
- 기대값 출처:
  - [spec.md](../../docs/changes/HEJO-TIDY-20261126/spec.md) 3절
  - HEJO-ALERT-SEEN spec REQ-AS-01·02와 수락 시험 AT-AS-01·09·10
  - HEJO-DISCORD-SECTIONS 수락 시험 6판, HEJO-TELEGRAM-REMOVE 수락 시험 5판
- 증거 수준: 공통 5절 2. M-01만 4.

| 시험 | AC | 입력·절차 | 기대값 | 기준본 기대 |
|---|---|---|---|---|
| AT-TIDY-01 | 01.AC-01 | `git merge-base --is-ancestor <원격 tip> <통합>`, `--is-ancestor a6d5e9a <통합>`, `--is-ancestor 1ca2cbb <통합>` | 셋 다 종료 0 | — |
| AT-TIDY-02 | 01.AC-02 | 통합 트리에서 실행: DISCORD-SECTIONS 6판 시험, TELEGRAM-REMOVE 5판 시험(AT-HTR-04 통합 비교 포함), OWNER-PROFILE 시험, ALERT-SEEN 시험(`test_history_queries.py`, `history_transport_app.py`), 런타임 Python `scripts/scan_private.py`, `bash app/scripts/build.sh` | 각각 종료 0 | — |
| AT-TIDY-02a | 01.AC-01a | 규격 JSON 의미 비교 세 번. T0 = 시작 원격 tip, M1 = 병합 1 커밋, M2 = 최종 커밋. ① `T0:schemas/hejo-wire-v1.json` 대 `M1:` ② `M1:` 대 `M2:` ③ `T0:` 대 `M2:`. 최종 트리에서 AT-HTR-04 상시 검사와 AT-DK-22 6판 (a)(b)(c)도 실행 | ① 차이 = `$defs.discord_layout` 추가 + `clientFrame.oneOf`·루트 `oneOf`에 `#/$defs/discord_layout` 각 1개 추가, 그 외 0 ② M2 = M1에서 `$defs`의 `telegram*` 6종과 그 `$ref` 항목만 뺀 값 ③ 차이 = ①의 추가 + ②의 제거, 그 외 0. AT-SM-02 해시 = sha256(M2 규격). 상시 검사 종료 0 | — |
| AT-TIDY-03 | 01.AC-03 | 원격 tip 기준선과 통합에서 전체 pytest JUnit·`bash scripts/test.sh` | 새 실패·오류 0. 노드 증감은 TELEGRAM-REMOVE AT-HTR-32의 허용 목록과 DISCORD-SECTIONS 신규 노드만 | 기준선 실패 목록 기록 |
| AT-TIDY-04 | 02.AC-01·02 | 임시 폴더 A에 자기(빌드 10)와 같은 ID 사본 빌드 9·10·11을 만든다(최소 `Contents/Info.plist`). 정리 실행 | 휴지통 처리기 호출 = 빌드 9 사본 1건. 나머지와 자기는 그대로 | 재현(기능 없음) |
| AT-TIDY-04b | 02.AC-01b | 임시 폴더 A(시스템 폴더 역할)·B(사용자 폴더 역할)를 정리 대상 목록으로 주입. A·B에 각각 같은 ID 빌드 9 사본. (i) 자기(빌드 10)를 A에 둠 (ii) 자기를 B에 둠 | (i)(ii) 각각 처리기 호출 = A의 사본 1건 + B의 사본 1건, 정확히 2건. 자기는 그대로 | 재현 |
| AT-TIDY-05 | 02.AC-03 | 폴더 A에 다른 ID 빌드 1, Info.plist 없는 `x.app`, `CFBundleVersion`="abc"인 같은 ID 사본 | 처리기 호출 0건 | 재현 |
| AT-TIDY-06 | 02.AC-04 | 자기 경로가 두 응용 프로그램 폴더 밖(예: 임시 `build/hejo.app`). 같은 폴더 목록에 빌드 9 사본 | 처리기 호출 0건 | 재현 |
| AT-TIDY-07 | 02.AC-05·06 | 폴더 A의 하위 폴더 `sub/old.app`(빌드 9), 그리고 실행 중 목록에 들어 있는 빌드 9 사본 | 처리기 호출 0건 | 재현 |
| AT-TIDY-08 | 02.AC-07 | 빌드 9 사본 두 개, 처리기가 첫 번째에서 오류를 던짐 | 두 번째는 처리기 호출됨. 첫 번째는 남음. 정리 함수는 오류 없이 반환한다 | 재현 |
| AT-TIDY-08b | 02.AC-10 | AT-TIDY-04·08의 실행에서 로그 기록기를 주입하거나 관측 | 옮긴 사본마다 원래 경로·빌드·결과 경로 한 줄, 실패 사본마다 원래 경로·빌드·오류 한 줄. AT-TIDY-05처럼 대상이 없으면 0줄 | 재현 |
| AT-TIDY-09 | 02.AC-09 | 정적: `install/get-hejo`에서 `/Applications/hejo.app`을 여는 줄 검색. 앱 쪽 판정 외 정리 로직(`Trash`, `trashItem`, 같은 ID 검색)이 `install/`에 없음 | `open /Applications/hejo.app`이 두 모드 모두에 있음. `install/`에 정리 로직 0건 | 보존(첫 조건), 보존(둘째 조건) |
| AT-TIDY-10 | 03.AC-01 | 공개 `AGENTS.md`, 개발 `AGENTS.md` 검색 `hejo-backups` | 각 1줄 이상 | — |
| AT-TIDY-11 | 04.AC-01 | `gate/tests/history_transport_app.py` `test_alert_seen`에 시나리오 `bubble`(펫 말풍선 클릭)과 `island`(섬 클릭)를 추가. 각각 알림 스레드 1건, 창 보임 상태 | 각 시나리오에서 그 key의 `notice` 1건·`thread` 0건 → `bell:`=`thread:`=최대 seq → 스냅숏 카드 없음(AT-AS-01과 같음) | **보존**. 현재 코드에서 통과해야 한다. 실패하면 제품을 고치지 말고 멈추고 보고 |
| AT-TIDY-12 | 05.AC-01·02 | `test_history_queries.py`의 AT-AS-09 표에 추가: `"@acct \n요약: 가짜"` → `"@acct · 요약: 가짜"`, `"  @a @b\t\n본문"` → `"@a @b · 본문"` | 기대값 그대로 | 재현(공백 두 칸) |
| AT-TIDY-13 | 05.AC-03 | 기존 AT-AS-09·10 | 모두 통과 | 보존 |
| AT-TIDY-14 | 06.AC-01·02 | HEJO-RELEASE 절차: 버전 커밋 R → `git update-ref refs/heads/public R <이전값>` → 깨끗한 트리에서 `bash app/scripts/build.sh` → `install/hejo-ship prepare --output <새 폴더>`(키체인 허가 창이 뜨면 사용자 승인) | `git diff --name-only R^ R` = Info.plist·`tests/acceptance/test_ship.py`. `CFBundleVersion` = 원격 tip 값 + 1. `codesign --verify --deep --strict` 0. BuildInfo tree = R 트리, dirty false. prepare 종료 0, 출력 폴더에 zip과 `prepared.json` 정확히 둘. `prepared.json` commit = R, version·build = 새 값, sha256 = `shasum -a 256 <zip>`. `test_ship.py` 종료 0 | — |
| AT-TIDY-14b | 06.AC-03 | 사용자 `hejo-ship publish` 뒤(읽기): `gh release view v<버전> --repo <공개 저장소> --json assets,isDraft` | isDraft false. 자산 = zip(크기·sha256이 `prepared.json`과 같음) + `appcast.xml` | — |
| AT-TIDY-15 | 07.AC-01 | 감사 목록 문서 검토(계획 담당). 범위 표 = `git ls-files` 결과에서 spec REQ-TIDY-07의 제외 경로만 뺀 목록(`tests/`·`githooks/`·`config/` 포함) | 범위 표의 경로 수 = `git ls-files` 수 − 제외 수. 제외마다 이유가 있음. 후보 항목마다 경로:줄·분류·검색 근거·영향. `tests/acceptance/` 명세·기대값 후보는 "기획 승인 필요"로 표시 | — |
| AT-TIDY-16 | 07.AC-02·03 | 정리 전후 전체 pytest JUnit, `bash scripts/test.sh`, `scan_private`, 앱 빌드, `schemas/` JSON 의미 비교 | 통과·실패 노드 목록이 같음. 빠진 노드는 승인 목록의 "함께 지울 시험"과 정확히 같음. 규격 의미 변화 없음 | 기준선 기록 |
| M-01 | 02.AC-08 | 실물. 선행: AT-TIDY-14b. 각 Mac(이 서버 Mac, 사장 맥북)에서:<br>① 설치 전 목록: `/Applications`·`~/Applications` 최상위 `*.app`마다 경로·`CFBundleIdentifier`·`CFBundleVersion`(`defaults read <app>/Contents/Info`)<br>② 갱신 직전 실행 중 hejo 목록: `pgrep -x hejo` → `ps -o comm= -p <pid>`로 번들 경로<br>③ Sparkle 또는 `get-hejo`로 갱신. 갱신 경로 U = 갱신이 교체한 번들(Sparkle은 실행 중이던 번들, `get-hejo`는 `/Applications/hejo.app`). 새 판을 1회 실행<br>④ 분류(R2-01). N = 새 빌드 번호. **갱신 경로** = U. **적격** = U가 아니고, 같은 ID이고, 빌드 < N이고, 새 판 실행 시점에 실행 중이 아닌 번들(②의 목록과 새 판 실행 시점의 `ps`로 판정). **보존** = 그 밖의 모든 번들(다른 ID, 빌드 ≥ N, 읽을 수 없는 번들, 실행 중이던 낮은 빌드 사본)<br>⑤ 같은 목록을 다시 만든다. `log show --last 30m --predicate 'subsystem == "io.github.hermes-hejo.hejo" AND category == "stale-copies"'`, 실행 중 프로세스 경로와 그 번들의 `CFBundleVersion`<br>⑥ 사용자가 Finder 휴지통에서 적격 이름을 확인한다(에이전트 셸은 휴지통을 읽을 수 없음).<br>맥북은 사용자가 ①②⑤ 명령을 실행해 출력을 붙인다 | **갱신 경로**: 같은 자리에 있고 `CFBundleVersion` = N이며, 실행 중 hejo의 실행 파일 경로 = `U/Contents/MacOS/hejo`. **적격**마다: 원래 경로에 없음 + 로그에 그 경로의 이동 줄(결과 경로가 휴지통 아래) + 사용자 휴지통 확인. **보존**마다: 원래 경로에 그대로(실행 중이던 사본 포함), 로그에 이동 줄 없음 | — |
