#!/usr/bin/env bash
# 视频节奏分析脚本 — 提取时长/规格/场景切换点/关键帧
# 用法: bash analyze_video.sh "<视频路径>" <输出目录>

set -euo pipefail

VIDEO="${1:?用法: analyze_video.sh <视频路径> <输出目录>}"
OUTDIR="${2:?用法: analyze_video.sh <视频路径> <输出目录>}"

mkdir -p "$OUTDIR"

echo "===== 元数据 ====="
ffprobe -v error -show_entries format=duration,size,bit_rate \
  -show_entries stream=index,codec_type,codec_name,width,height,r_frame_rate,channels \
  -of default=noprint_wrappers=1 "$VIDEO"

DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")
FPS=30
N=$(python -c "print(int($DUR * $FPS))")

echo ""
echo "===== 场景切换点 (阈值0.1) ====="
ffmpeg -hide_banner -i "$VIDEO" -vf "select='gt(scene,0.1)',showinfo" -f null - 2>&1 \
  | grep -oE "pts_time:[0-9.]+" || echo "(无明显硬切)"

echo ""
echo "===== 提取 11 张均匀关键帧 -> $OUTDIR ====="
# 均匀取帧：n = round(i * (N-1) / 10), i=0..10
SEL=$(python - "$N" <<'EOF'
import sys
n = int(sys.argv[1])
frames = [round(i * (n - 1) / 10) for i in range(11)]
print("+".join(f"eq(n\\,{f})" for f in frames))
EOF
)
ffmpeg -v error -i "$VIDEO" -vf "select='${SEL}',scale=360:-1" -fps_mode passthrough \
  "$OUTDIR/%02d.jpg"

ls "$OUTDIR"
echo ""
echo "完成。用 Read 工具逐张查看关键帧，按 format-spec.md 提取 beat sheet。"
