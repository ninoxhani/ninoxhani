#!/usr/bin/env bash
# Download Binance XAUUSDT perpetual 1-minute klines (public data, no account needed) and build
# research/xau_m1.npz.  Usage:  bash research/download_data.sh  (from the project folder)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DATA="${1:-$HOME/albfx_research_data}"   # keep downloads outside the repository (untrusted data)
mkdir -p "$DATA"
BASE=https://data.binance.vision/data/futures/um
for m in 2025-12 2026-01 2026-02 2026-03 2026-04 2026-05 2026-06 2026-07 2026-08 2026-09 2026-10; do
  curl -fsS -o "$DATA/XAUUSDT-1m-$m.zip" "$BASE/monthly/klines/XAUUSDT/1m/XAUUSDT-1m-$m.zip"
done
for d in 01 02 03 04 05 06 07 08 09 10; do
  curl -fsS -o "$DATA/XAUUSDT-1m-2026-11-$d.zip" "$BASE/daily/klines/XAUUSDT/1m/XAUUSDT-1m-2026-11-$d.zip"
done
python3 -I "$HERE/load_data.py" "$DATA" "$HERE/xau_m1.npz"
