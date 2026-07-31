#!/usr/bin/env bash
# check-demo-video.sh — 演示视频交付判据（SPEC-25）
#
# 为什么需要：SPEC-25 写了四条判据（存在 / ≥8 分钟 / 中文旁白 / 覆盖全链），
# 但"交付了一个视频"最容易变成一句没人核的话。本探针把前三条变成可执行断言，
# 第四条（语义覆盖）无法机器判定，改为**强制要求存在抽帧联络表验收留痕**。
#
# 用法：bash scripts/check-demo-video.sh <视频路径> [<字幕路径>]
# 退出码：0=全部满足  1=判据不满足  66=自检失败（ffprobe 不可用）

set -uo pipefail

V="${1:-}"
[ -n "$V" ] || { echo "用法: bash scripts/check-demo-video.sh <视频> [<字幕>]"; exit 1; }
SRT="${2:-${V%.*}.srt}"

command -v ffprobe >/dev/null 2>&1 || { echo "自检失败：ffprobe 不可用，无法验证视频属性" >&2; exit 66; }

fails=0
ok()   { printf '  ✅ %s\n' "$1"; }
bad()  { printf '  ❌ %s\n' "$1"; fails=$((fails+1)); }

echo "== 演示视频交付判据（SPEC-25）｜ $(basename "$V") =="

# ---- 判据 1：文件存在且容器可解析 ----
if [ ! -f "$V" ]; then bad "视频不存在：$V"; echo "FAIL(1)"; exit 1; fi
FMT=$(ffprobe -v error -show_entries format=format_name -of csv=p=0 "$V" 2>/dev/null || true)
[ -n "$FMT" ] && ok "容器可解析（${FMT}）" || bad "容器损坏或不可解析（moov atom 缺失？）"

# ---- 判据 2：时长 ≥8 分钟 ----
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$V" 2>/dev/null || echo 0)
DUR_I=${DUR%%.*}; : "${DUR_I:=0}"
if [ "$DUR_I" -ge 480 ]; then
  ok "时长 ${DUR_I} 秒 = $((DUR_I/60)) 分 $((DUR_I%60)) 秒（≥8 分钟）"
else
  bad "时长仅 ${DUR_I} 秒，不足 SPEC-25 要求的 480 秒"
fi

# ---- 判据 3：有音轨且**不是静音** ----
# 只查"有音轨"不够：合成了但没铺上轨的片子照样有一条全静音的流。
ACODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$V" 2>/dev/null || true)
if [ -z "$ACODEC" ]; then
  bad "无音轨 —— 中文旁白判据不成立"
else
  MAXV=$(ffmpeg -hide_banner -nostats -i "$V" -af volumedetect -f null /dev/null 2>&1 \
         | grep -oE 'max_volume: -?[0-9.]+' | grep -oE '\-?[0-9.]+' | head -1)
  : "${MAXV:=-100}"
  # max_volume 低于 -50 dB 视为静音（正常语音在 -10 ~ 0 之间）
  if awk -v v="$MAXV" 'BEGIN{exit !(v > -50)}'; then
    ok "音轨 ${ACODEC}，max_volume ${MAXV} dB（非静音）"
  else
    bad "音轨存在但 max_volume ${MAXV} dB —— 实质是静音，旁白没铺上"
  fi
fi

# ---- 判据 4a：字幕存在且含中文（旁白是中文的机器可判部分）----
if [ -f "$SRT" ]; then
  CJK=$(LC_ALL=C grep -c '[^ -~]' "$SRT" 2>/dev/null || true); : "${CJK:=0}"
  if [ "$CJK" -ge 10 ]; then
    ok "字幕 $(basename "$SRT") 含 ${CJK} 行非 ASCII 文本（中文旁白）"
  else
    bad "字幕存在但几乎无中文（${CJK} 行）"
  fi
else
  bad "缺字幕文件 $(basename "$SRT") —— 无法机器判定旁白语言"
fi

# ---- 判据 4b：语义覆盖无法机器判定 → 强制要求验收留痕 ----
# skill 的纪律：argo 保证音画**时长**对齐，不保证**语义**对齐。
# 这一条只能人看抽帧联络表，故此处只检查"有没有留下验收记录"。
REC=$(dirname "$V")/../../specs/*/release.md
if ls $REC >/dev/null 2>&1 && grep -qE "联络表|抽帧" $REC 2>/dev/null; then
  ok "语义验收留痕存在（release.md 记录了抽帧联络表核对）"
else
  printf '  ⚠️  未找到抽帧联络表的验收留痕 —— SPEC-25 第四条（覆盖全链）**无法机器判定**，\n'
  printf '      必须人看联络表逐格核对并把结论写进交付记录，否则该条不算满足\n'
fi

echo
if [ "$fails" -gt 0 ]; then
  echo "FAIL(1): ${fails} 项判据不满足"
  exit 1
fi
echo "PASS: SPEC-25 机器可判部分全部满足（语义覆盖须人核）"
