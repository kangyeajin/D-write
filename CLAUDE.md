# D-write 프로젝트 규칙

## 브랜치 정책 (강제)

- 모든 기능 개발 및 코드 수정은 `feature/<기능명>` 브랜치에서 작업
- **main 직접 커밋 차단됨** (git pre-commit hook + Claude Code PreToolUse hook)
- 훅 파일: `.claude/hooks/check-master-branch.sh`, `.git/hooks/pre-commit`

### 작업 흐름

```
# 작업 시작
git checkout -b feature/<기능명>

# 작업 완료 후 merge (fast-forward)
git checkout main
git merge feature/<기능명>   # --no-ff 금지 — 브랜치 커밋이 main에 그대로 남도록
```

- fast-forward merge 사용: "Merge feature/... → main" 형태의 병합 커밋 생성 금지
- 브랜치 작업 커밋이 main 히스토리에 직접 남도록 유지

---

## 로깅 규칙 (Flutter 프로젝트)

### 기본 원칙

- 로그는 `debugPrint`만 사용한다. `print`는 금지.
- release 빌드에서 자동 제거되므로 별도 조건문(`kDebugMode`) 불필요.
- 로그 메시지는 `[TAG] 내용` 형식으로 작성한다.

### 태그 규칙

| 태그 | 사용 범위 |
|------|-----------|
| `[LAUNCH]` | 앱 초기화 단계 (`main.dart`) |
| `[QUOTE]` | 문장 로드 및 추천 흐름 |
| `[ATTEND]` | 출석 체크 및 Firestore 동기화 |
| `[AUTH]` | 인증 상태 변경 (로그인/로그아웃/회원가입) |
| `[NAV]` | 화면 이동 |
| `[MEMO]` | 메모 저장/수정/삭제 흐름 |
| `[ERROR]` | 예외 및 오류 (기존 catch 블록의 `debugPrint` 대체) |

### 작성 규칙

- 성공 경로: `[TAG] 동작 완료 — 결과값`
- 분기 진입: `[TAG] 조건=값 → 분기 설명`
- 실패/폴백: `[TAG] 실패 원인 → 폴백 동작`
- 수량 포함 시: `(N개)` 형태로 뒤에 붙인다

### 새 기능 개발 시

1. 기능의 핵심 흐름 진입점에 `[TAG] 시작` 로그 추가
2. 주요 분기마다 조건과 결과를 로그로 남긴다
3. catch 블록의 기존 `debugPrint`는 `[ERROR]` 태그로 통일한다
4. 로그 확인 방법은 `docs/shared/logging-guide.md` 참고
