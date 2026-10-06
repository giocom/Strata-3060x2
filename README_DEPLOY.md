# Strata 배포 및 운영 가이드 (10.11.60.146)

## 1. 서버 사양 분석 및 최적화 구성

10.11.60.146 서버에 접속하여 하드웨어 리소스를 점검하고 다음 구성으로 최적화하였습니다.

| 항목 | 서버 사양 | Strata 설정 및 최적화 |
|---|---|---|
| **GPU** | 2x NVIDIA GeForce RTX 3060 (12GB VRAM 각, 총 24GB, sm_86) | `GPUS=all`, `LAYER_SPLIT=auto`<br>두 GPU에 모델 레이어를 분할(Layer Split) 배치 |
| **GPU P2P** | **Peer-to-Peer 활성화 상태 (OK)** | GPU 간 PCIe 직접 메모리 접근(P2P) 활성화로 통신 병목 최소화 |
| **시스템 RAM** | 48 GiB (가용 메모리 ~46 GiB) | `MODEL=IQ2_XS` (Arena ~35.5GB 사용, 48GB RAM 환경 최적)<br>`Q2_0` (Arena ~34.0GB, 최고 속도)도 선택 가능 |
| **CPU** | AMD Ryzen 7 5700G (7 vCPUs, AVX2 지원) | CPU 스레드 풀을 통한 MoE Expert 연산 지원 |
| **스토리지** | `/data` (가용 공간 약 78~91 GB) | 모델 GGUF 및 런타임 캐시를 위한 마운트 (`./data:/data`) |
| **컨텍스트** | **130k 요구사항** | `CONTEXT=131072` (128K = 약 130k 토큰) |
| **동시 요청** | **4 동시요청 요구사항** | `PARALLEL=4` (엔진 `--batch 4` 슬롯 할당) |
| **KV 캐시** | - | `KV=q4_0`, `KV_STREAMING=auto`<br>130k 컨텍스트 4개 슬롯이 12GB VRAM 내에서 OOM 없이 구동되도록 4-bit KV 양자화 및 스트리밍 활성화 |
| **멀티모달** | **비전(Vision) 기능 지원** | `BUILD_VISION=1`, `VISION=yes`<br>`strata-vision` GPU 전용 인코더 빌드 완료, 이미지 입력 지원 |

---

## 2. 주요 설정 파일 안내 (`/data/Strata`)

- **`docker-compose.yml`**: GPU 패스스루, 메모리 락(`memlock: -1`), 볼륨 마운트 및 멀티모달 지원 서비스 정의
- **`.env`**: 환경 변수 (모델, 컨텍스트 길이, 동시 요청 수, KV 양자화, 멀티모달 비전 등)
- **`docker-entrypoint.sh`**: 컨테이너 기동 시 최초 모델 및 비전 프로젝터(`mmproj`) 자동 다운로드 및 엔진 설정 반영 스크립트

---

## 3. 서비스 실행 및 관리 방법

### (1) 서비스 실행
```bash
cd /data/Strata
docker compose up -d
```

> **참고 (최초 실행 시)**:
> 최초 기동 시 모델 파일(~70 GB) 및 비전 프로젝터(~1 GB)를 Hugging Face에서 자동으로 다운로드하고 엔진 프로파일을 준비합니다.
> 다운로드 진행 상황은 아래 로그 명령어로 실시간 확인할 수 있습니다.

### (2) 실시간 로그 확인
```bash
docker compose logs -f
```

### (3) 상태 확인
- 헬스체크:
  ```bash
  curl http://localhost:8080/health
  ```
- 엔진 및 모델 상세 상태:
  ```bash
  curl http://localhost:8080/v1/status
  ```

### (4) 서비스 중지 및 재시작
- 중지:
  ```bash
  docker compose down
  ```
- 재시작:
  ```bash
  docker compose restart
  ```

---

## 4. API 사용 예시 (텍스트 및 멀티모달 비전)

Strata는 OpenAI 호환 API 엔드포인트를 제공합니다.

### 텍스트 질의 (최대 4개 동시 요청 병렬 처리)
```bash
curl http://10.11.60.146:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.8-flash-next",
    "messages": [
      {"role": "user", "content": "안녕하세요! 자기소개를 해주세요."}
    ],
    "temperature": 0.7
  }'
```

### 멀티모달 이미지 질의 (Vision API)
```bash
curl http://10.11.60.146:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.8-flash-next",
    "messages": [
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "이 이미지에 대해 설명해 주세요."},
          {
            "type": "image_url",
            "image_url": {
              "url": "data:image/jpeg;base64,<BASE64_IMAGE_STRING>"
            }
          }
        ]
      }
    ]
  }'
```
