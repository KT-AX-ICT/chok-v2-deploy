# 서비스 레포용 CI 템플릿

각 서비스 레포가 자기 `.github/workflows/ci.yml`로 복사해서 쓰는 템플릿 모음.
`test`(언어별 검사)와 `build`(공통 재사용 워크플로우 호출) 두 잡으로 구성된다.

## 쓰는 법

1. 아래 파일을 자기 레포의 `.github/workflows/ci.yml`로 복사
   - FastAPI → `ci-fastapi.yml`
   - Spring → `ci-spring.yml`
   - Frontend → `ci-frontend.yml`
   - SDK → `ci-sdk.yml`
2. `test` 잡을 레포 실제 빌드 도구에 맞게 조정(주석 참고)
3. 커밋·머지하면 main push 시 자동으로: 이미지 빌드 → GHCR push → 배포 레포에 digest PR 생성

## 전제 (한 번만)

- 조직 시크릿 `DEPLOY_BOT_APP_ID`, `DEPLOY_BOT_PRIVATE_KEY`(자동 PR용 GitHub App)
- 레포가 Public이라 재사용 워크플로우 Access 설정은 불필요

## 서비스별 값

| 서비스 | image_name | service_key | Dockerfile |
|--------|-----------|-------------|------------|
| FastAPI | `chok-v2-ai-backend` | `fastapi` | 있음 |
| Spring | `chok-v2-spring-backend` | `spring` | 있음 |
| Frontend | `chok-v2-react-frontend` | `frontend` | ⚠️ 필요(node→nginx) |
| SDK | `chok-v2-py-sdk` | `sdk` | ⚠️ 필요(python, `rca-collect` 실행) |

Frontend·SDK는 Dockerfile이 레포에 있어야 `build` 잡이 통과한다. 없으면 우선 `test` 잡만 유지.
FastAPI는 원격에 `tests.yml`이 이미 있으면 테스트 중복 정리 필요(`ci-fastapi.yml` 상단 주석 참고).
