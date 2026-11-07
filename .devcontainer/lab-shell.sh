# lab.env의 모든 줄을 export한다(set -a). 예: COMMERCE_WORKSPACE=/home/vscode/commerce-admin → .../commerce-admin/work/lab.env
commerce_load_lab_env() {
  local lab_env_file="${COMMERCE_WORKSPACE:-$HOME}/work/lab.env"
  if [ -f "$lab_env_file" ]; then
    set -a
    # shellcheck source=/dev/null
    . "$lab_env_file"
    set +a
  fi
}
commerce_load_lab_env
