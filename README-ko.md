# Strata-3060x2

NVIDIA GeForce RTX 3060 12GB 2장(Dual GPU, 총 24GB VRAM) 및 48GB 시스템 RAM 환경에서 **Qwen3.8-Flash-Next**를 **130k 컨텍스트**, **동시 4개 요청 병렬 처리**, **멀티모달 비전(Vision)**까지 완벽하게 구동할 수 있도록 Docker화 및 최적화한 저장소입니다.

---

## 1. 주요 특징 및 하드웨어 최적화

| 구분 | 사양 및 설정 | 최적화 내용 |
|---|---|---|
| **GPU** | 2x NVIDIA GeForce RTX 3060 (12GB VRAM x 2 = 총 24GB, sm_86) | `GPUS=all`, `LAYER_SPLIT=auto`<br>모델 레이어를 두 GPU에 파이프라인 분할하여 GPU당 가중치 및 KV 캐시 부담 분산 |
| **GPU P2P** | **PCIe Peer-to-Peer 활성화** (`OK`) | GPU 0과 GPU 1 간 호스트 RAM 버퍼를 거치지 않고 PCIe 직결 통신으로 레이어 핸드오프 레이턴시 최소화 |
| **시스템 RAM** | 48 GiB | `MODEL=IQ2_XS` (Arena 메모리 ~35.5GB 사용으로 48GB 환경에 최적화)<br>`Q2_0` (최고 속도), `IQ1_M` (Coder) 선택 가능 |
| **컨텍스트** | **130k 토큰 지원** | `CONTEXT=131072` (128K = 약 130k 토큰) |
| **동시 요청** | **4개 동시 요청 병렬 디코딩** | `PARALLEL=4` (엔진 `--batch 4` 슬롯 활성화) |
| **KV 캐시** | `KV=q4_0`, `KV_STREAMING=auto` | 130k 컨텍스트 x 4 슬롯이 12GB VRAM 내에서 OOM 없이 작동하도록 4-bit KV 양자화 및 자동 스트리밍 활성화 |
| **멀티모달** | **비전(Vision) 기능 지원** | `BUILD_VISION=1`, `VISION=yes`<br>`strata-vision` GPU 전용 인코더 빌드 완료, 이미지 입력 및 분석 지원 |

---

## 2. 주요 수정 및 커스텀 내역

본 저장소는 업스트림([Niko1221/Strata](https://github.com/Niko1221/Strata)) 기반에서 듀얼 RTX 3060 환경의 프로덕션 운영을 위해 다음과 같은 사항들이 수정 및 추가되었습니다.

### (1) `docker-entrypoint.sh` 환경변수 전달 및 동적 동기화 패치
- **업스트림 이슈 수정**: 기존 엔트리포인트는 `PARALLEL`, `KV_STREAMING` 환경 변수를 정의하거나 `setup.py` CLI 옵션(`--parallel`, `--kv-streaming`)으로 전달하지 못하여 배치 슬롯 설정이 무시되던 문제를 수정했습니다.
- **동적 설정 동기화 추가**: 이미 다운로드/설정된 `strata-<model>.json` 파일이 존재하더라도, `.env` 또는 Docker 환경변수로 변경된 `PARALLEL`, `PORT`, `HOST`, `API_KEY` 값이 컨테이너 재시작 시 자동으로 JSON 설정에 동기화되도록 로직을 추가했습니다.
- **기본값 최적화**: 기본 `CONTEXT`를 `131072`, `PARALLEL`을 `4`, `KV`를 `q4_0`, `VISION`을 `yes`, `GPUS`를 `all`로 설정했습니다.

### (2) `docker-compose.yml` 신규 작성
- **Dual GPU 패스스루**: NVIDIA Container Toolkit의 `deploy.resources.reservations.devices` (`count: all`) 설정 적용.
- **sm_86 타겟 최적화 빌드**: RTX 3060 아키텍처에 맞춘 `CUDA_ARCHITECTURES=86` 및 멀티모달 비전 인코더 포함 `BUILD_VISION=1` 빌드 파라미터 적용.
- **시스템 권한 설정**: 대용량 RAM 락을 위한 `ulimits: memlock: -1, stack: 67108864` 및 빠른 IPC 통신을 위한 `ipc: host` 적용.
- **데이터 영속성**: `./data:/data` 볼륨 바인드 마운트로 호스트에 모델 파일 및 런타임 캐시 영속화.

### (3) `.env` 및 `.env.example` 작성
- 모델 양자화 크기(`MODEL`), 컨텍스트 길이(`CONTEXT`), 동시 처리 슬롯 수(`PARALLEL`), KV 캐시 압축(`KV`), 비전 활성화(`VISION`) 등을 손쉽게 제어할 수 있는 설정 템플릿 구성.

### (4) `.gitignore` 보강
- 다운로드되는 대용량 모델 가중치 파일(70GB+) 및 런타임 생성 파일(`data/`, `*.part`, `*.done` 등)이 Git에 커밋되지 않도록 안전하게 제외 처리.

---

## 3. 설치 및 실행 방법

### 사전 요구사항
- NVIDIA GPU 드라이버 (CUDA 13+ 지원, Driver 580+)
- Docker 및 Docker Compose (NVIDIA Container Toolkit 설치 필요)
- 시스템 RAM 48GB 이상, 여유 디스크 공간 80GB 이상

### (1) 저장소 클론 및 환경 설정
```bash
git clone git@github.com:giocom/Strata-3060x2.git
cd Strata-3060x2

# 필요시 환경변수 수정 (.env 파일)
cp .env.example .env  # 또는 기본 제공되는 .env 사용
```

### (2) Docker 이미지 빌드 및 실행
```bash
# Docker 이미지 빌드 (sm_86 및 비전 인코더 포함)
docker compose build

# 서비스 백그라운드 실행
docker compose up -d
```

> **최초 실행 시 안내**:
> 최초 실행 시 Hugging Face에서 모델 가중치(~70 GB) 및 비전 프로젝터(`mmproj`, ~1 GB)를 자동으로 다운로드하고 엔진 프로파일을 준비합니다.
> 다운로드 진행 상황은 아래 로그 명령어로 확인할 수 있습니다.

### (3) 로그 및 상태 모니터링
```bash
# 실시간 컨테이너 로그 확인
docker compose logs -f

# 헬스체크 확인
curl http://localhost:8080/health

# 엔진 및 리소스 상태 확인 (컨텍스트, GPU 사용량, 동시성 등)
curl http://localhost:8080/v1/status
```

### (4) 서비스 중지 및 재시작
```bash
# 서비스 중지
docker compose down

# 서비스 재시작
docker compose restart
```

---

## 4. API 사용 예시 (OpenAI 호환)

Strata는 OpenAI 및 Anthropic 호환 API 엔드포인트를 기본 제공합니다.

### (1) 일반 텍스트 질의 (동시 최대 4개 요청 병렬 디코딩)
```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.8-flash-next",
    "messages": [
      {"role": "user", "content": "안녕하세요! 130k 컨텍스트 지원 모델인가요?"}
    ],
    "max_tokens": 100
  }'
```

### (2) 멀티모달 이미지 질의 (Vision API)
```bash
IMAGE_PATH="/path/to/your/image.jpg"
IMAGE_B64=$(base64 -w 0 "$IMAGE_PATH")

curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"qwen3.8-flash-next\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": [
          {\"type\": \"text\", \"text\": \"이 사진에 무엇이 있는지 한 문장으로 설명해 주세요.\"},
          {
            \"type\": \"image_url\",
            \"image_url\": {
              \"url\": \"data:image/jpeg;base64,${IMAGE_B64}\"
            }
          }
        ]
      }
    ],
    \"max_tokens\": 100
  }"
```

---

## 5. 라이선스

- 본 저장소의 코드는 [MIT License](LICENSE)를 따릅니다.
- 모델 가중치([Qwen3.8-Flash-Next](https://huggingface.co/Qwen/Qwen3.8-Flash-Next)) 및 양자화 가중치는 해당 배포처의 라이선스를 따릅니다.
