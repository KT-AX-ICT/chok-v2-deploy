# chok-v2 기본 배포

MySQL, Spring, FastAPI, Frontend, SDK를 Docker Compose로 실행하는 기본 구성입니다.

SDK는 원래 로그·메트릭·트레이스가 만들어지는 외부 서버에서 실행한다고 가정합니다. 현재는 환경 제약 때문에 중앙 서비스와 같은 서버에서 실행하며, 호스트의 관측 데이터 디렉터리를 읽기 전용으로 연결합니다.

## 배포 흐름

```text
서비스 저장소 main 병합
→ CI 테스트
→ GHCR에 Git commit SHA 태그 이미지 발행
→ 자동화가 deploy 저장소의 docker-compose.yml 이미지 digest 변경 PR 생성
→ 사람이 원본 commit·CI 결과·이미지 digest를 확인하고 PR 병합
→ AWS 배포 자동화로 인계
```

PR 병합 이후의 실제 배포 방식은 AWS 구성 확정 후 별도로 작성합니다. 아래 Compose 명령은 로컬 통합 테스트와 수동 점검용이며 AWS 운영 배포 절차가 아닙니다.

`main`, `latest` 같은 이동 태그는 배포 버전으로 사용하지 않습니다. 각 서비스의 `image:`는 GHCR 이미지 digest인 `@sha256:...` 형식으로 고정합니다. 자동 PR은 변경된 서비스의 이미지 한 줄만 수정하고, PR 본문에 원본 commit, GHCR 태그, digest, CI 링크를 남깁니다.

## 파일

- `docker-compose.yml`: GHCR 이미지를 실행하는 기본 구성
- `docker-compose.local.yml`: 서비스 저장소 소스를 직접 빌드할 때만 사용하는 추가 구성
- `.env`: 비밀번호, API key, URL, 포트, SDK 수집 경로. Git에 올리지 않습니다.
- `.env.example`: `.env` 작성 예시
- `mysql/init/01-create-databases.sh`: 서비스별 DB와 계정 생성

다른 서비스 저장소와 같은 `docker-compose.yml` 이름을 사용하므로 기본 명령에는 `-f`가 필요하지 않습니다.

## 로컬 통합 실행

```bash
cp .env.example .env
# .env의 비밀번호, API key, 공개 URL, SDK_SOURCE_PATH를 수정
# docker-compose.yml의 0으로 된 임시 digest가 실제 GHCR digest로 교체됐는지 확인

docker compose pull
docker compose up -d
docker compose ps
```

기본 접속 주소는 다음과 같습니다.

- Frontend: <http://localhost:4173>
- Spring API: <http://localhost:8080/api/reports>
- FastAPI 문서: <http://127.0.0.1:8000/docs>
- MySQL: `127.0.0.1:3307`
- SDK: 외부 포트 없이 `http://fastapi:8000/ingest`로 전송

`SDK_SOURCE_PATH`에는 `log/`, `metric/`, `trace/` 하위 디렉터리가 있는 호스트 경로를 지정합니다. SDK 컨테이너에서는 이 경로를 `/data/source`로 읽습니다.

SDK 이미지는 기본 실행 명령으로 `rca-collect`를 시작해야 합니다.

## 서비스별 명령

서비스 이름은 `mysql`, `spring`, `fastapi`, `frontend`, `sdk`입니다. 아래 예시의 `spring`을 원하는 서비스 이름으로 바꿔 사용합니다.

```bash
# 실행 또는 변경된 설정으로 재생성
docker compose up -d spring

# 중지
docker compose stop spring

# 재시작
docker compose restart spring

# 로그 확인
docker compose logs -f spring

# 새 이미지로 해당 서비스만 갱신
docker compose pull spring
docker compose up -d --no-deps spring
```

`docker compose down`은 전체 프로젝트를 종료하고 네트워크를 정리할 때 사용합니다. 서비스 하나만 중지할 때는 `stop <서비스명>`을 사용합니다.

## 로컬에서 이미지 직접 빌드

deploy 저장소와 네 서비스 저장소가 같은 상위 디렉터리에 있어야 합니다.

```text
services/
├── chok-v2-deploy/
├── backend-spring/
├── api-fastapi/
├── frontend/
└── py-sdk/
```

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build
```

각 서비스 저장소에 Dockerfile이 있어야 합니다. Frontend와 SDK Dockerfile이 `main`에 병합되기 전에는 전체 로컬 빌드를 사용할 수 없습니다.

## DB 관리

deploy 저장소는 MySQL에 다음 DB와 전용 계정만 만듭니다.

- Spring: `chokchok`
- FastAPI: `chok_ai`

테이블 변경은 Spring 이미지의 Flyway와 FastAPI 이미지의 Alembic이 처리합니다. deploy 저장소에는 서비스 테이블 SQL을 복사하지 않습니다.

MySQL 초기화 스크립트는 빈 볼륨의 최초 실행에서만 동작합니다. 기존 DB에 계정을 추가할 때는 데이터를 삭제하지 말고 관리자 권한으로 초기화 SQL을 한 번 실행합니다.

## 종료와 로컬 데이터 초기화

```bash
# DB 데이터 유지
docker compose down

# 로컬 MySQL 데이터까지 삭제
docker compose down -v
```

`down -v`로 삭제한 MySQL 데이터는 백업이 없으면 복구할 수 없습니다.
