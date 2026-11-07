# shellcheck shell=bash
# 새 bash 터미널마다 한 번 읽는 실습 환경 설정. image의 /usr/local/share/commerce/lab-shell.sh에 들어가고,
# templates의 postCreateCommand가 ~/.bashrc에 ". /usr/local/share/commerce/lab-shell.sh" 한 줄을 더한다.
#   1) <workspace>/work/lab.env가 있으면 변수로 읽는다(INFRA_ROOT, GITHUB_ORG, *_ACCOUNT_ID 등). 교안 블록마다 source하지 않는다.
#   2) 실습 Python venv(/opt/commerce-python)를 PATH 앞에 둔다.
#   3) prompt에 지금 AWS profile과 kubectl context를 보여 준다. 예: [dev-operator | commerce-dev-eks] ~/commerce-platform$
# COMMERCE_WORKSPACE와 기본 AWS_PROFILE은 devcontainer.json의 remoteEnv가 넣는다.

# 실습 Python 도구 venv(image의 /opt/commerce-python, hash 고정 의존성)를 python3보다 앞에 둔다.
# devcontainer feature가 PATH 앞에 다른 python을 넣어도 make gitops-check·make test가 이 venv를 쓰게 한다.
case ":$PATH:" in
  *":/opt/commerce-python/bin:"*) ;;
  *) PATH="/opt/commerce-python/bin:$PATH" ;;
esac

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

# context가 아직 없으면(첫 make kubeconfig 전) 빈칸으로 둔다. prompt마다 오류 문구가 찍히지 않게 stderr는 버린다.
commerce_prompt_context() {
  kubectl config current-context 2>/dev/null
}
PS1='[${AWS_PROFILE:-no-profile} | $(commerce_prompt_context)] \w\$ '
