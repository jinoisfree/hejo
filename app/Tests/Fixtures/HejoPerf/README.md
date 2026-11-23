# HEJO-PERF 기준 입력과 관측 결과

TASK-01A에서 동결한 기준. 수락 기준 원본은 계획 담당의 `tests/acceptance/HEJO-PERF.md`다. 이 자료는 제품 수정 전 관측값이며 AT-HP 합격 판정이 아니다.

- `input.json`: 가짜 프레임·사용자 동작 58단계와 성능 부하 조건. 운영 기록을 복사하지 않는다.
- `expected.json`: 기준 HEAD에서 실제 GateClient/Controller/Model을 실행한 단계별 관측 결과. 수정 구현으로 재생성하거나 덮어쓰지 않는다.
- `baseline.json`: 기준 커밋·제품 소스 tree·입력/결과 SHA-256 및 정규화 규칙.

정규화는 최초 동결 전에 하네스에 정했다. fixture에 없는 자동 생성 선택 스레드 UUID만 `<generated-thread>`로 표시한다. 집합·사전 순회 결과는 정렬하며 타임라인·스레드·알림 순서는 그대로 보존한다. 회원 상태의 벽시계 메타데이터와 typing 만료 시각은 제외하고 실제 값·존재 여부를 관측한다. 기본 시계와 명시적 now의 알림을 각각 관측한다. 프레임의 파일·버튼은 비어 있으며 첨부·실제 네트워크 송신의 검증을 대신하지 않는다.

확인된 Python을 `hejo_python`에 지정하고, 캐시된 Sparkle 위치가 기본 빌드 폴더와 다르면 `HEJO_PERF_SPARKLE_DIR`로 지정한다. 설치된 Python/본체/운영 앱을 변경하지 않는다.

```sh
"$hejo_python" app/Tests/hejo_perf.py check --evidence .build/hejo-perf-evidence/comparison
"$hejo_python" app/Tests/hejo_perf.py measure --no-build --evidence .build/hejo-perf-evidence/comparison
"$hejo_python" app/Tests/hejo_perf.py home --no-build --evidence .build/hejo-perf-evidence/comparison
"$hejo_python" app/Tests/hejo_perf.py regression --no-build --evidence .build/hejo-perf-evidence/comparison
```

각 명령은 지정한 증거 폴더의 `<mode>/`에 출력·로그를 보존한다. 원래 기준 증거 폴더는 수정 제품으로 덮어쓸 수 없다. 같은 출력 경로가 이미 있으면 빌드 전 실패한다. 기존 증거를 보관한 뒤 재실행한다. `--no-build`는 소스·빌드 옵션·컴파일러·실행 파일 해시가 빌드 영수증과 같은 경우에만 허용한다. `freeze`는 기준 HEAD·미동결 상태·제품 소스 무변경을 확인하며 재동결을 거부한다. `home`은 같은 부하를 홈에서 시작하는 별도 측정이며 `regression`은 실제 View와 기존 열기/닫기 캡처 검사를 실행한다. 측정 결과의 `budgets.json`은 수락 명세의 수치 예산 검사다.

성능은 `-O`, Swift 5 언어 모드, arm64/macOS 13 이상 대상으로 실제 AppKit 화면을 실행한다. 가짜 방 8개 × 스레드 100개 × 글 4개, 질문/알림/완료/스트리밍을 섞고 입력 순서와 시계를 고정한다. 840×760 창에 View를 연결하되 화면에 창을 표시하지 않는다. 초기 로딩 후 한 번 warm-up, 별도 LocalStore/View로 5회 측정한다. 각 측정은 편집 프레임 4개를 한 개씩 메인 큐에 전달한다. 첫 통지 안에서 NSTextView 입력과 방 전환을 큐에 넣어 대기 시간과 수신 종료 전 처리 여부를 기록한다. 명시적으로 새 스케줄을 측정하는 시험이며 실제 소켓 도착 빈도나 OS 키보드 지연의 증거가 아니다.

수신 비용은 캐시 store.append 직전부터 Controller.receive의 동기 화면 통지 반환까지이며 append를 포함한다. refresh 비용은 onChange가 호출하는 실제 View.refresh 범위이며 중첩 비용이 포함될 수 있어 단순 합산하지 않는다. CPU는 같은 측정 구간의 프로세스 user+system CPU 증가량/벽시계 경과로 계산한다(한 코어 100%). 초기 로딩·View 생성·최초 layout·기준 의미 관측은 성능 구간에서 제외한다. 설치 앱의 수신 빈도·체감 응답성은 별도 관측 대상이다.
