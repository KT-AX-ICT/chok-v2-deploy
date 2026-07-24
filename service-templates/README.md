# 서비스 레포 → Docker 이미지 적용 가이드

각 서비스 레포가 자기 코드를 **GHCR 이미지로 만들어 배포 레포(chok-v2-deploy)에 자동 반영**하도록 CI를 붙이는 방법. 여기 있는 `ci-*.yml`을 자기 레포 `.github/workflows/ci.yml`로 복사해서 쓴다.

## 이미지 파이프라인 한눈에

```
service repo (main push)
  └─ ci.yml
       ├─ test  : 언어별 검사(레포마다 다름)
       └─ build : 공통 재사용 워크플로우 호출
             → 이미지 빌드 → GHCR push(sha 태그)
             → chok-v2-deploy/docker-compose.yml 의 해당 서비스 digest 갱신 PR 자동 생성
```

- 배포 버전은 이동 태그가 아니라 **GHCR digest(@sha256:…)** 로 고정된다.
- `build` 잡은 `KT-AX-ICT/chok-v2-deploy/.github/workflows/reusable-docker-build.yml@main` 을 호출한다.
- 사람이 그 자동 PR을 확인·머지해야 실제 배포 compose에 반영된다.

## 전제 (조직에서 한 번만)

- 조직 시크릿 `DEPLOY_BOT_APP_ID`, `DEPLOY_BOT_PRIVATE_KEY` (자동 PR용 GitHub App).
  App 권한: Repository → Contents(RW), Pull requests(RW), `chok-v2-deploy`에 install.
- 서비스 레포가 Public이면 재사용 워크플로우 Access 설정 불필요.

## 각 레포 적용 절차 (공통)

1. 자기 레포에 **Dockerfile**이 있는지 확인 (아래 "레포별 Dockerfile 요건").
2. 해당 `ci-*.yml`을 `.github/workflows/ci.yml`로 복사.
3. `test` 잡을 레포 실제 빌드 도구에 맞게 조정(템플릿 상단 주석 참고).
4. main에 머지 → 자동으로 이미지 빌드 → GHCR push → deploy 레포에 digest PR 생성.

## 서비스별 값 · 현재 상태 (2026-07-24)

| 서비스 | image_name | service_key | 템플릿 | Dockerfile | CI 상태 / 할 일 |
|--------|-----------|-------------|--------|-----------|-----------------|
| FastAPI | `chok-v2-ai-backend` | `fastapi` | `ci-fastapi.yml` | ✅ 있음 | 원격 main에 `tests.yml`+`deploy-image.yml` 병존 → **통합 `ci.yml` 한 벌로 정리 필요**(중복 제거). ruff 정리 선행 PR 진행 중 |
| Spring | `chok-v2-spring-backend` | `spring` | `ci-spring.yml` | ⚠️ **없음** | **Dockerfile·CI 둘 다 없음 → 배포 blocker.** 추가 전까지 compose의 spring digest는 `0000…` |
| Frontend | `chok-v2-react-frontend` | `frontend` | `ci-frontend.yml` | ✅ 있음(node→nginx) | 원격에 워크플로우 없음 → `ci-frontend.yml` 복사만 하면 됨 |
| SDK | `chok-v2-py-sdk` | — | (없음) | 🗑 제거 대상 | **로컬 실행 결정(2026-07-24) → 배포 이미지 없음.** `ci-sdk.yml` 삭제됨. SDK Dockerfile 제거 + compose의 `sdk` 서비스 제거 예정 |

## 레포별 Dockerfile 요건

- **FastAPI** (`chok-v2-ai-backend`): uv 설치 → uvicorn 실행. 이미 있음.
- **Spring** (`chok-v2-spring-backend`): JDK 21 빌드(`./gradlew bootJar`) → 런타임 JRE. **추가 필요.**
- **Frontend** (`chok-v2-react-frontend`): node 빌드 → nginx 서빙 멀티스테이지. 이미 있음.
- **SDK** (`chok-v2-py-sdk`): 배포 컨테이너로 올리지 않음(로컬 실행) → Dockerfile 불필요.

`build` 잡은 레포에 Dockerfile이 있어야 통과한다. 없으면 우선 `test` 잡만 두고 `build`는 Dockerfile 추가 후 붙인다.

## 주의

- **테스트 중복**: 레포에 이미 `tests.yml`이 있는데 `ci-fastapi.yml`(test 포함)을 또 넣으면 테스트가 두 벌, deploy PR도 두 개(같은 `deploy/<service_key>` 브랜치 충돌)가 된다. **CI는 레포당 한 벌로 통일**할 것.
- **OpenAI 키(FastAPI만)**: test 잡이 앱을 import하므로 `OPENAI_API_KEY: sk-test-dummy` 를 test 잡 env에 넣어야 한다(실호출은 없음, SQLite in-memory).
