# 개발 컨테이너 공식 Ubuntu 24.04 이미지(vscode 사용자 포함)를 버전 태그와 index digest로 고정한다.
# digest 확인(예): docker buildx imagetools inspect mcr.microsoft.com/devcontainers/base:3.0.10-ubuntu24.04 --format '{{.Manifest.Digest}}'
# 이 image에는 Docker CLI·Host Docker 소켓 연결을 넣지 않는다. image build는 CI(build-image.yml)에서 한다.
FROM mcr.microsoft.com/devcontainers/base:3.0.10-ubuntu24.04@sha256:21e9e3275736cb3bc33a2904b279a2ab292c51fedd53c2963463627d4586c3e6

# 팀 표준 도구 버전을 한곳에 고정한다. 올릴 때는 이 값만 바꾼다.
ARG TERRAFORM_VERSION=1.16.0
ARG TFLINT_VERSION=0.64.0
ARG KUBECTL_VERSION=1.35.9
ARG HELM_VERSION=3.21.2
ARG KUSTOMIZE_VERSION=5.8.1
ARG KUBECONFORM_VERSION=0.8.0
ARG ISTIOCTL_VERSION=1.30.8
ARG ARGOCD_VERSION=3.5.2
ARG ARGO_ROLLOUTS_VERSION=1.10.0
ARG KYVERNO_VERSION=1.19.2
ARG COSIGN_VERSION=3.1.3
ARG SYFT_VERSION=1.51.1
ARG TRIVY_VERSION=0.74.0
ARG GITLEAKS_VERSION=8.30.1
ARG SEMGREP_VERSION=1.182.0
ARG CRANE_VERSION=0.20.6
ARG AWSCLI_VERSION=2.36.44
ARG SSM_PLUGIN_VERSION=1.2.896.0
# Session Manager plugin .deb 의 SHA-256(CPU별). AWS 배포 파일을 받아 직접 계산해 넣는다.
#   예: curl -fsSLO https://s3.amazonaws.com/session-manager-downloads/plugin/1.2.896.0/ubuntu_64bit/session-manager-plugin.deb && sha256sum session-manager-plugin.deb
ARG SSM_PLUGIN_SHA256_AMD64=53f51fcc67314a4bf85888a38a3967cd41f8d0f28a60a9469a63acf935ba713e
ARG SSM_PLUGIN_SHA256_ARM64=914eeca87b18b55356c58be197080f73742b3ca60d3823f0a45670dc9056aa9c
# AWS CLI 설치 안내에 적힌 AWS CLI 공개 key의 fingerprint. key 파일이 이 key가 아니면 빌드가 멈춘다.
ARG AWSCLI_PGP_FINGERPRINT=FB5DB77FD5C118B80511ADA8A6310ACC4672475C
ARG CMCTL_VERSION=2.6.1
ARG VELERO_VERSION=1.18.1
# velero release CHECKSUM 파일의 값(linux-amd64·linux-arm64 tar.gz)
ARG VELERO_SHA256_AMD64=f483cf07b0fa09f33d91f264528492f362e031afa85546b47cbfdf9f77662067
ARG VELERO_SHA256_ARM64=d5ca8652502a58b270d73cbea4e3ac8be91733edddbd6d2c09a6ef0f3a3d1308
ARG YQ_VERSION=4.53.6
# 빌드 대상 CPU 종류(amd64 또는 arm64)를 BuildKit이 플랫폼마다 채운다.
ARG TARGETARCH

# 파이프 중간 명령이 실패해도 그 자리에서 빌드를 멈춘다.
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# 다운로드·압축 해제·서명 검증·DNS 확인·UUID 생성에 쓰는 기본 패키지를 설치한다.
# make: infra repository의 Makefile(make eks-tunnel, make validate 등). perl은 base image에 있다(init-template·bump script).
# postgresql-client: 개인 IAM DB 접속(15-10, psql + SSM port forwarding). Ubuntu 24.04 기본 psql 16으로 RDS PostgreSQL 17에 접속한다.
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl dnsutils jq unzip python3-venv gnupg uuid-runtime postgresql-client make \
 && rm -rf /var/lib/apt/lists/*

# 자격 증명 폴더를 vscode 소유로 미리 만든다. 없으면 mount할 때 Docker가 root 소유로 만든다.
# 관리용·개발용 container만 이 경로에 Host 폴더(~/eks-tutorial-01/.credentials/admin/*, ~/eks-tutorial-01/.credentials/dev/*)를 mount한다. sandbox는 mount하지 않는다.
RUN mkdir -p /home/vscode/.aws /home/vscode/.config/gh /home/vscode/.kube \
 && chown -R vscode:vscode /home/vscode/.aws /home/vscode/.config /home/vscode/.kube

# 내려받은 파일은 임시 폴더에 두고, 단계마다 비운다.
WORKDIR /tmp/tools

# Mike Farah yq: YAML을 편집하며 platform별 공식 release SHA-256으로 확인합니다.
RUN case "${TARGETARCH}" in \
      amd64) YQ_SHA256=c5f056448f973ae7d39b5401949648a78f2dc1947d6a8eb65be60d5c504b9385 ;; \
      arm64) YQ_SHA256=88a1016bc1d657375a35864e4f44b6f333df8ff97b559f51bba0adcb2169df09 ;; \
      *) exit 1 ;; \
    esac \
 && curl -fsSLo yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_${TARGETARCH}" \
 && echo "${YQ_SHA256}  yq" | sha256sum --check \
 && install -m 0755 yq /usr/local/bin/yq \
 && rm -f yq

# Terraform: 공식 SHA256SUMS로 검증한다. 값이 다르면 빌드가 멈춘다.
RUN curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
 && curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
 && sha256sum --check --ignore-missing "terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
 && unzip -o "terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" terraform -d /usr/local/bin \
 && rm -rf /tmp/tools/*

# tflint: 릴리스의 checksums.txt로 검증한다.
RUN curl -fsSLO "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${TARGETARCH}.zip" \
 && curl -fsSLO "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/checksums.txt" \
 && sha256sum --check --ignore-missing checksums.txt \
 && unzip -o "tflint_linux_${TARGETARCH}.zip" tflint -d /usr/local/bin \
 && rm -rf /tmp/tools/*

# kubectl: 같은 주소의 .sha256 파일(해시 값만 들어 있음)로 검증한다.
RUN curl -fsSLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
 && curl -fsSLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" \
 && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check \
 && install -m 0755 kubectl /usr/local/bin/kubectl \
 && rm -rf /tmp/tools/*

# helm: 압축 파일 옆의 .sha256sum으로 검증하고 helm 실행 파일만 꺼낸다.
RUN curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
 && curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz.sha256sum" \
 && sha256sum --check "helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz.sha256sum" \
 && tar -xzf "helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" -C /usr/local/bin --strip-components=1 "linux-${TARGETARCH}/helm" \
 && rm -rf /tmp/tools/*

# kustomize: 릴리스의 checksums.txt로 검증한다(태그 이름이 kustomize/v<버전>이라 /를 %2F로 쓴다).
RUN curl -fsSLO "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/checksums.txt" \
 && sha256sum --check --ignore-missing checksums.txt \
 && tar -xzf "kustomize_v${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz" -C /usr/local/bin kustomize \
 && rm -rf /tmp/tools/*

# kubeconform: 릴리스의 CHECKSUMS로 검증한다.
RUN curl -fsSLO "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-${TARGETARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/CHECKSUMS" \
 && sha256sum --check --ignore-missing CHECKSUMS \
 && tar -xzf "kubeconform-linux-${TARGETARCH}.tar.gz" -C /usr/local/bin kubeconform \
 && rm -rf /tmp/tools/*

# istioctl: 압축 파일 옆의 .sha256으로 검증한다.
RUN curl -fsSLO "https://github.com/istio/istio/releases/download/${ISTIOCTL_VERSION}/istioctl-${ISTIOCTL_VERSION}-linux-${TARGETARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/istio/istio/releases/download/${ISTIOCTL_VERSION}/istioctl-${ISTIOCTL_VERSION}-linux-${TARGETARCH}.tar.gz.sha256" \
 && sha256sum --check "istioctl-${ISTIOCTL_VERSION}-linux-${TARGETARCH}.tar.gz.sha256" \
 && tar -xzf "istioctl-${ISTIOCTL_VERSION}-linux-${TARGETARCH}.tar.gz" -C /usr/local/bin istioctl \
 && rm -rf /tmp/tools/*

# argocd CLI: 릴리스의 cli_checksums.txt로 검증한다.
RUN curl -fsSLO "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-${TARGETARCH}" \
 && curl -fsSLO "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/cli_checksums.txt" \
 && sha256sum --check --ignore-missing cli_checksums.txt \
 && install -m 0755 "argocd-linux-${TARGETARCH}" /usr/local/bin/argocd \
 && rm -rf /tmp/tools/*

# Argo Rollouts kubectl 플러그인: 릴리스의 argo-rollouts-checksums.txt로 검증한다.
RUN curl -fsSLO "https://github.com/argoproj/argo-rollouts/releases/download/v${ARGO_ROLLOUTS_VERSION}/kubectl-argo-rollouts-linux-${TARGETARCH}" \
 && curl -fsSLO "https://github.com/argoproj/argo-rollouts/releases/download/v${ARGO_ROLLOUTS_VERSION}/argo-rollouts-checksums.txt" \
 && sha256sum --check --ignore-missing argo-rollouts-checksums.txt \
 && install -m 0755 "kubectl-argo-rollouts-linux-${TARGETARCH}" /usr/local/bin/kubectl-argo-rollouts \
 && rm -rf /tmp/tools/*

# kyverno CLI: 릴리스의 checksums.txt로 검증한다(파일 이름의 CPU 표기는 x86_64·arm64).
RUN case "${TARGETARCH}" in amd64) KYVERNO_ARCH=x86_64 ;; arm64) KYVERNO_ARCH=arm64 ;; esac \
 && curl -fsSLO "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/kyverno-cli_v${KYVERNO_VERSION}_linux_${KYVERNO_ARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/kyverno/kyverno/releases/download/v${KYVERNO_VERSION}/checksums.txt" \
 && sha256sum --check --ignore-missing checksums.txt \
 && tar -xzf "kyverno-cli_v${KYVERNO_VERSION}_linux_${KYVERNO_ARCH}.tar.gz" -C /usr/local/bin kyverno \
 && rm -rf /tmp/tools/*

# cosign: 릴리스의 cosign_checksums.txt로 검증한다.
RUN curl -fsSLO "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${TARGETARCH}" \
 && curl -fsSLO "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign_checksums.txt" \
 && sha256sum --check --ignore-missing cosign_checksums.txt \
 && install -m 0755 "cosign-linux-${TARGETARCH}" /usr/local/bin/cosign \
 && rm -rf /tmp/tools/*

# syft: 릴리스의 syft_<버전>_checksums.txt로 검증한다.
RUN curl -fsSLO "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_checksums.txt" \
 && sha256sum --check --ignore-missing "syft_${SYFT_VERSION}_checksums.txt" \
 && tar -xzf "syft_${SYFT_VERSION}_linux_${TARGETARCH}.tar.gz" -C /usr/local/bin syft \
 && rm -rf /tmp/tools/*

# trivy: 릴리스의 trivy_<버전>_checksums.txt로 검증한다(파일 이름의 CPU 표기는 64bit·ARM64).
RUN case "${TARGETARCH}" in amd64) TRIVY_ARCH=64bit ;; arm64) TRIVY_ARCH=ARM64 ;; esac \
 && curl -fsSLO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt" \
 && sha256sum --check --ignore-missing "trivy_${TRIVY_VERSION}_checksums.txt" \
 && tar -xzf "trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" -C /usr/local/bin trivy \
 && rm -rf /tmp/tools/*

# Gitleaks의 amd64 배포 파일 이름은 x64입니다.
RUN case "${TARGETARCH}" in amd64) GITLEAKS_ARCH=x64 ;; arm64) GITLEAKS_ARCH=arm64 ;; esac \
 && curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt" \
 && sha256sum --check --ignore-missing "gitleaks_${GITLEAKS_VERSION}_checksums.txt" \
 && tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_${GITLEAKS_ARCH}.tar.gz" -C /usr/local/bin gitleaks \
 && rm -rf /tmp/tools/*

# crane은 image index와 OCI layout을 다룹니다.
RUN case "${TARGETARCH}" in amd64) CRANE_ARCH=x86_64 ;; arm64) CRANE_ARCH=arm64 ;; esac \
 && curl -fsSLO "https://github.com/google/go-containerregistry/releases/download/v${CRANE_VERSION}/go-containerregistry_Linux_${CRANE_ARCH}.tar.gz" \
 && curl -fsSLO "https://github.com/google/go-containerregistry/releases/download/v${CRANE_VERSION}/checksums.txt" \
 && sha256sum --check --ignore-missing checksums.txt \
 && tar -xzf "go-containerregistry_Linux_${CRANE_ARCH}.tar.gz" -C /usr/local/bin crane \
 && rm -rf /tmp/tools/*

# 시스템 Python과 분리하고 설치된 의존성 목록을 image에 보존합니다.
RUN python3 -m venv /opt/semgrep \
 && /opt/semgrep/bin/python -m pip install --no-cache-dir "semgrep==${SEMGREP_VERSION}" \
 && /opt/semgrep/bin/python -m pip freeze > /opt/semgrep/requirements.lock \
 && ln -s /opt/semgrep/bin/semgrep /usr/local/bin/semgrep

# 실습 Python 검사 도구의 의존성(jsonschema·PyYAML 등)을 hash 고정 목록으로 venv에 미리 넣는다.
# make gitops-check·make test·tests/security/vulnerability-cases·ci.release.* 가 이 venv의 python3로 돈다.
# container 안에서는 pip install을 하지 않는다. 목록은 infra repository의 requirements-delivery.txt와 같고, 바뀌면 image를 다시 build한다.
# PATH 앞에 둬서 터미널의 python3가 이 venv를 가리키게 한다(lab-shell.sh도 새 터미널마다 같은 순서로 맞춘다).
COPY requirements-python-tools.txt /opt/commerce-python/requirements.txt
RUN python3 -m venv /opt/commerce-python \
 && /opt/commerce-python/bin/python -m pip install --no-cache-dir --require-hashes -r /opt/commerce-python/requirements.txt \
 && /opt/commerce-python/bin/python -m pip freeze > /opt/commerce-python/requirements.lock
ENV PATH="/opt/commerce-python/bin:${PATH}"

# cmctl: 인증서 갱신 시험용 CLI를 고정 release 체크섬으로 검증한다.
RUN curl -fsSLO "https://github.com/cert-manager/cmctl/releases/download/v${CMCTL_VERSION}/cmctl_linux_${TARGETARCH}" \
 && curl -fsSLO "https://github.com/cert-manager/cmctl/releases/download/v${CMCTL_VERSION}/checksums.txt" \
 && sha256sum --check --ignore-missing checksums.txt \
 && install -m 0755 "cmctl_linux_${TARGETARCH}" /usr/local/bin/cmctl \
 && rm -rf /tmp/tools/*

# velero CLI: 백업·복원(12-09·12-10·19장)을 velero 명령으로 한다. 서버(chart 12.1.0 = velero 1.18.1)와 같은 버전.
# 체크섬은 release의 CHECKSUM 파일에서 가져와 ARG로 고정한다.
RUN case "${TARGETARCH}" in \
      amd64) VELERO_SHA256="${VELERO_SHA256_AMD64}" ;; \
      arm64) VELERO_SHA256="${VELERO_SHA256_ARM64}" ;; \
    esac \
 && curl -fsSLo velero.tar.gz "https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-${TARGETARCH}.tar.gz" \
 && echo "${VELERO_SHA256}  velero.tar.gz" | sha256sum --check \
 && tar -xzf velero.tar.gz \
 && install -m 0755 "velero-v${VELERO_VERSION}-linux-${TARGETARCH}/velero" /usr/local/bin/velero \
 && rm -rf /tmp/tools/*

# AWS CLI v2: 버전 지정 주소에서 설치 파일과 서명(.sig)을 받는다(파일 이름의 CPU 표기는 x86_64·aarch64).
# 임시 keyring에 공개 key 하나만 넣고 fingerprint를 대조한 뒤 서명을 검증한다. 하나라도 실패하면 빌드가 멈춘다.
COPY awscli-public-key.asc /tmp/awscli-public-key.asc
RUN case "${TARGETARCH}" in amd64) AWS_ARCH=x86_64 ;; arm64) AWS_ARCH=aarch64 ;; esac \
 && curl -fsSLo awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}-${AWSCLI_VERSION}.zip" \
 && curl -fsSLo awscliv2.sig "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}-${AWSCLI_VERSION}.zip.sig" \
# GNUPGHOME: 서명 검증에만 쓰는 임시 keyring. 사용자 keyring과 섞이지 않고 image에 남지 않게 mktemp로 만들고 이 RUN 끝에서 지운다.
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --batch --import /tmp/awscli-public-key.asc \
 && test "$(gpg --batch --with-colons --list-keys | grep -c '^pub:')" = 1 \
 && gpg --batch --list-keys "${AWSCLI_PGP_FINGERPRINT}" \
 && gpg --batch --verify awscliv2.sig awscliv2.zip \
 && unzip -q awscliv2.zip \
 && ./aws/install \
 && gpgconf --kill all \
 && rm -rf "${GNUPGHOME}" /tmp/awscli-public-key.asc /tmp/tools/*

# Session Manager plugin: AWS 공식 .deb를 CPU에 맞는 경로에서 받아 SHA-256을 대조한 뒤 설치한다.
# 값이 다르면(파일 변조·버전 불일치) 빌드가 멈춘다.
RUN case "${TARGETARCH}" in \
      amd64) SSM_ARCH=ubuntu_64bit; SSM_SHA256="${SSM_PLUGIN_SHA256_AMD64}" ;; \
      arm64) SSM_ARCH=ubuntu_arm64; SSM_SHA256="${SSM_PLUGIN_SHA256_ARM64}" ;; \
      *) exit 1 ;; \
    esac \
 && curl -fsSLo session-manager-plugin.deb "https://s3.amazonaws.com/session-manager-downloads/plugin/${SSM_PLUGIN_VERSION}/${SSM_ARCH}/session-manager-plugin.deb" \
 && echo "${SSM_SHA256}  session-manager-plugin.deb" | sha256sum --check \
 && dpkg -i session-manager-plugin.deb \
 && rm -rf /tmp/tools/*

# 새 터미널마다 lab.env를 읽고 prompt에 profile·context를 보이는 설정. templates의 postCreateCommand가 ~/.bashrc에서 부른다.
COPY lab-shell.sh /usr/local/share/commerce/lab-shell.sh

# 임시 폴더를 지우고 기본 작업 위치를 루트로 돌린다.
WORKDIR /
RUN rm -rf /tmp/tools
