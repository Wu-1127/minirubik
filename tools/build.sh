#!/bin/sh
# Assemble one Ripes source file from the pieces.
# Ripes (v2.2.6-106) has no .if directive, so builds are selected here
# by choosing which files to concatenate and which .equ values to prepend.
#
# Usage: tools/build.sh MODE [STATE]
#   MODE   measure     solve one state (all --iret figures)
#          tests       in-program tests
#          render      GUI build with the LED matrix (FRAME_DELAY may be set)
#          render_cli  CLI check of the renderer: LED memory replaced by RAM,
#                      every frame printed as text
#          render3d    GUI build of the 3D cube with animated face turns
#                      (FRAME_DELAY and CAM_YAW, in 1/32 turns, may be set)
#          render3d_cli  CLI check of the 3D renderer, every frame printed as text
#   STATE  optional 14-digit state for measure / render / render_cli
# Output: asm/build/ida_MODE.s (path printed on stdout)
set -e
mode=$1
state=$2
case "$mode" in
  measure|tests)
    prefix=""
    parts="asm/main_$mode.s asm/solver.s asm/tables.s" ;;
  render)
    prefix=".equ DUMP, 0
.equ FRAME_DELAY, ${FRAME_DELAY:-20000}"
    parts="asm/main_render.s asm/solver.s asm/render.s asm/tables.s" ;;
  render_cli)
    prefix=".equ LED_MATRIX_0_BASE, 0x20000000
.equ DUMP, 1
.equ FRAME_DELAY, 0"
    parts="asm/main_render.s asm/solver.s asm/render.s asm/tables.s" ;;
  render3d)
    prefix=".equ DUMP, 0
.equ FRAME_DELAY, ${FRAME_DELAY:-3000}
.equ CAM_YAW, ${CAM_YAW:-28}"
    parts="asm/main_render3d.s asm/solver.s asm/render.s asm/render3d.s asm/tables.s" ;;
  render3d_cli)
    prefix=".equ LED_MATRIX_0_BASE, 0x20000000
.equ DUMP, 1
.equ FRAME_DELAY, 0
.equ CAM_YAW, ${CAM_YAW:-28}"
    parts="asm/main_render3d.s asm/solver.s asm/render.s asm/render3d.s asm/tables.s" ;;
  *)
    echo "unknown mode: $mode" >&2; exit 2 ;;
esac
mkdir -p asm/build
out=asm/build/ida_$mode.s
{
  [ -n "$prefix" ] && printf '%s\n' "$prefix"
  for f in $parts; do cat "$f"; echo; done
} > "$out.tmp"
if [ -n "$state" ]; then
  sed "s/\.string \"[0-9]*\"/.string \"$state\"/" "$out.tmp" > "$out"
  rm "$out.tmp"
else
  mv "$out.tmp" "$out"
fi
echo "$out"
