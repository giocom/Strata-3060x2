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

## 2. 실제 환경 성능 실측 데이터 (듀얼 RTX 3060 벤치마크)

실제 구동 환경(`2x NVIDIA GeForce RTX 3060 12GB`, `AMD Ryzen 7 5700G`, `48GB RAM`, `PCIe P2P 활성화`)에서 대규모 프롬프트(~47k 토큰) 및 코딩 에이전트 도구 호출(Tool Call) 수행 시 측정한 실측 런타임 성능 데이터입니다.

### 📊 실측 성능 지표 요약

| 항목 | 실측치 | 세부 분석 |
|---|---|---|
| **프롬프트 처리 (Prefill)** | **약 16,000 ~ 23,500 tok/s** | 약 47,000개 토큰(~47k) 프롬프트를 **단 2~3초** 만에 처리 완료 |
| **추론 속도 (Thinking & Answering)** | **27.0 ~ 30.9 tok/s** | CoT 추론, 자연어 답변, Tool Call 생성 전반에서 초당 27~31토큰의 안정적인 생성 속도 유지 |
| **GPU Expert 캐시 적중률** | **70.1% ~ 76.3% Hit** | 듀얼 GPU(24GB VRAM)의 분할 캐시가 활성 Expert의 70% 이상을 직접 적중하여 고속 연산 수행 |
| **PCIe P2P 전송 비율** | **+1.3% ~ 2.1% PCIe 라우팅** | P2P 직결 통신으로 캐시 미스된 Expert도 CPU/PCIe 병목 없이 빠르게 분산 처리 |
| **도구 호출(Tool Calling)** | **정상 수행 완료** | `bash` 쉘 호출 등 에이전트 도구 호출(`writing a tool call`) 정상 수행 확인 |

### 📝 실제 런타임 로그

```text
# [턴 1] 47k 토큰 프롬프트 처리 및 툴 콜 생성 (Thinking + Answering + Bash Tool Call)
strata  | [strata] reading the prompt: 46,961 of 46,966 tokens, 2 s so far
strata  | [strata] thinking: 18 of max 16384 tokens, 27.1 tok/s, 3 s
strata  | [strata] thinking: 48 of max 16384 tokens, 28.0 tok/s, 4 s
strata  | [strata] thinking: 74 of max 16384 tokens, 27.0 tok/s, 5 s
strata  | [strata] thinking: 99 of max 16384 tokens, 26.3 tok/s, 6 s
strata  | [strata] thinking: 128 of max 16384 tokens, 26.8 tok/s, 7 s
strata  | [strata] thinking: 151 of max 16384 tokens, 26.1 tok/s, 8 s
strata  | [strata] thinking: 184 of max 16384 tokens, 27.1 tok/s, 9 s
strata  | [strata] thinking: 214 of max 16384 tokens, 27.4 tok/s, 10 s
strata  | [strata] thinking: 248 of max 16384 tokens, 28.0 tok/s, 11 s
strata  | [strata] thinking: 276 of max 16384 tokens, 28.0 tok/s, 12 s
strata  | [strata] thinking: 308 of max 16384 tokens, 28.1 tok/s, 14 s
strata  | [strata] thinking: 347 of max 16384 tokens, 28.9 tok/s, 15 s
strata  | [strata] answering: 382 of max 16384 tokens, 29.3 tok/s, 16 s
strata  | [strata] answering: 412 of max 16384 tokens, 29.2 tok/s, 17 s
strata  | [strata] writing a tool call: bash: 442 of max 16384 tokens, 29.2 tok/s, 18 s
strata  | [strata] writing a tool call: bash: 477 of max 16384 tokens, 29.5 tok/s, 19 s
strata  | [strata] writing a tool call: bash: 508 of max 16384 tokens, 29.5 tok/s, 20 s
strata  | [strata] writing a tool call: bash: 544 of max 16384 tokens, 29.7 tok/s, 21 s
strata  | [strata] writing a tool call: bash: 579 of max 16384 tokens, 30.0 tok/s, 22 s
strata  | [strata] writing a tool call: bash: 614 of max 16384 tokens, 30.2 tok/s, 23 s
strata  | [strata] writing a tool call: bash: 660 of max 16384 tokens, 30.8 tok/s, 24 s
strata  | [strata] done: 690 tokens in 25 s (30.9 tok/s) (stop, cancel=False), expert cache 70.1% hit (+2.1% of the routed experts over PCIe)

# [턴 2] 후속 질의 47.8k 토큰 처리 및 Thinking
strata  | [strata] reading the prompt: 47,844 of 47,849 tokens, 3 s so far
strata  | [strata] thinking: 15 of max 16384 tokens, 22.3 tok/s, 4 s
strata  | [strata] thinking: 42 of max 16384 tokens, 24.5 tok/s, 5 s
strata  | [strata] thinking: 69 of max 16384 tokens, 25.1 tok/s, 6 s
strata  | [strata] thinking: 98 of max 16384 tokens, 25.8 tok/s, 7 s
strata  | [strata] thinking: 131 of max 16384 tokens, 27.3 tok/s, 8 s
strata  | [strata] thinking: 157 of max 16384 tokens, 26.9 tok/s, 9 s
strata  | [strata] thinking: 178 of max 16384 tokens, 25.8 tok/s, 10 s
strata  | [strata] thinking: 203 of max 16384 tokens, 25.7 tok/s, 11 s
strata  | [strata] thinking: 236 of max 16384 tokens, 26.5 tok/s, 12 s
strata  | [strata] thinking: 267 of max 16384 tokens, 26.9 tok/s, 13 s
strata  | [strata] thinking: 300 of max 16384 tokens, 27.4 tok/s, 14 s
strata  | [strata] thinking: 330 of max 16384 tokens, 27.4 tok/s, 15 s
strata  | [strata] thinking: 364 of max 16384 tokens, 27.9 tok/s, 16 s
strata  | [strata] thinking: 395 of max 16384 tokens, 28.1 tok/s, 18 s
strata  | [strata] thinking: 423 of max 16384 tokens, 28.0 tok/s, 19 s
strata  | [strata] thinking: 455 of max 16384 tokens, 28.1 tok/s, 20 s
strata  | [strata] thinking: 489 of max 16384 tokens, 28.4 tok/s, 21 s
strata  | [strata] done: 490 tokens in 21 s (28.4 tok/s) (disconnect, cancel=True), expert cache 76.3% hit (+1.3% of the routed experts over PCIe)
```

---

## 3. 주요 수정 및 커스텀 내역

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

## 4. 설치 및 실행 방법

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

## 5. API 사용 예시 (OpenAI 호환)

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

## 6. 라이선스

- 본 저장소의 코드는 [MIT License](LICENSE)를 따릅니다.
- 모델 가중치([Qwen3.8-Flash-Next](https://huggingface.co/Qwen/Qwen3.8-Flash-Next)) 및 양자화 가중치는 해당 배포처의 라이선스를 따릅니다.
