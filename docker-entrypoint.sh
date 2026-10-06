#!/bin/sh
set -e
cd /opt/strata || exit 1

STRATA_DATA="${STRATA_DATA:-/data}"
FAMILY="${FAMILY:-qwen}"
MODEL="${MODEL:-IQ2_XS}"
CONTEXT="${CONTEXT:-131072}"
VISION="${VISION:-yes}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
API_KEY="${API_KEY:-}"
KV="${KV:-q4_0}"
GPUS="${GPUS:-all}"
GPU="${GPU:-}"
LAYER_SPLIT="${LAYER_SPLIT:-auto}"
LOW_RAM="${LOW_RAM:-auto}"
PARALLEL="${PARALLEL:-4}"
KV_STREAMING="${KV_STREAMING:-auto}"

case "$FAMILY" in qwen) prefix="" ;; *) prefix="${FAMILY}-" ;; esac
tag="${prefix}$(printf '%s' "$MODEL" | tr 'A-Z' 'a-z')"
cfg="$STRATA_DATA/config/strata-$tag.json"
mkdir -p "$STRATA_DATA/config"

if [ "${REINSTALL:-0}" = "1" ] || [ ! -f "$cfg" ]; then
  echo "================================================================="
  echo "Setting up Strata: $tag (Context: $CONTEXT, Parallel: $PARALLEL, KV: $KV, GPUs: $GPUS)"
  echo "Downloading model (~70 GB) and preparing engine configuration..."
  echo "================================================================="
  set -- --family "$FAMILY" --model "$MODEL" --context "$CONTEXT" --vision "$VISION" \
    --data-dir "$STRATA_DATA" --host "$HOST" --api-key "$API_KEY" \
    --port "$PORT" --no-start --low-ram "$LOW_RAM"
  if [ -n "$KV" ]; then set -- "$@" --kv "$KV"; fi
  if [ -n "$GPUS" ]; then set -- "$@" --gpus "$GPUS"; fi
  if [ -n "$GPU" ]; then set -- "$@" --gpu "$GPU"; fi
  if [ -n "$LAYER_SPLIT" ]; then set -- "$@" --layer-split "$LAYER_SPLIT"; fi
  if [ -n "$PARALLEL" ]; then set -- "$@" --parallel "$PARALLEL"; fi
  if [ -n "$KV_STREAMING" ]; then set -- "$@" --kv-streaming "$KV_STREAMING"; fi
  .venv/bin/python setup.py --setup --yes "$@"
  [ -e "/opt/strata/strata-$tag.json" ] && { cmp -s "/opt/strata/strata-$tag.json" "$cfg" || cp -f "/opt/strata/strata-$tag.json" "$cfg"; }
else
  [ -e "/opt/strata/strata-$tag.json" ] || ln -s "$cfg" "/opt/strata/strata-$tag.json"
fi

if [ -f "$cfg" ]; then
  .venv/bin/python -c "
import json
try:
    with open('$cfg', 'r', encoding='utf-8-sig') as f:
        c = json.load(f)
    changed = False
    if '$PARALLEL':
        c['parallel'] = int('$PARALLEL')
        changed = True
    if '$HOST':
        c['host'] = '$HOST'
        changed = True
    if '$PORT':
        c['port'] = int('$PORT')
        changed = True
    if '$API_KEY':
        c['api_key'] = '$API_KEY'
        changed = True
    if changed:
        with open('$cfg', 'w', encoding='utf-8') as f:
            json.dump(c, f, indent=2)
except Exception as e:
    print(f'[warning] failed to sync env to config: {e}')
"
fi

echo "================================================================="
echo "Starting Strata server on port $PORT (GPUS: $GPUS, Parallel: $PARALLEL)"
echo "================================================================="
set -- --port "$PORT"
if [ -n "$GPUS" ]; then set -- "$@" --gpus "$GPUS"; fi
if [ -n "$GPU" ]; then set -- "$@" --gpu "$GPU"; fi
if [ -n "$LAYER_SPLIT" ]; then set -- "$@" --layer-split "$LAYER_SPLIT"; fi
exec .venv/bin/python setup.py "$@"
