FROM alpine:3.12 AS builder
ENV HELM_VER=3.3.4
ENV KUBECTL_VER=1.18.1
ENV KUSTOMIZE_VER=3.8.4
ENV CURL_VER=7.69.1-r1

WORKDIR /

RUN apk update \
    && apk add --no-cache \
       curl="${CURL_VER}" \
    && rm -rf /var/cache/apk/*
RUN curl https://get.helm.sh/helm-v"${HELM_VER}"-linux-amd64.tar.gz --output helm.tar.gz \
    && tar -zxvf helm.tar.gz \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/v"${KUBECTL_VER}"/bin/linux/amd64/kubectl -o kubectl \
    && curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv"${KUSTOMIZE_VER}"/kustomize_v"${KUSTOMIZE_VER}"_linux_amd64.tar.gz -o kustomize.tar.gz \
    && tar -zxvf kustomize.tar.gz \
    && curl -L https://raw.githubusercontent.com/kubernetes-sigs/kustomize/kustomize/v"${KUSTOMIZE_VER}"/plugin/someteam.example.com/v1/chartinflator/ChartInflator -o ChartInflator \
    && chmod u+x kubectl linux-amd64/helm kustomize ChartInflator \
    && /kubectl version --client=true \
    && /kustomize version \
    && /linux-amd64/helm version

FROM alpine:3.12
ENV BASH_VER=5.0.17-r0
ENV GETTEXT_VER=0.20.2-r0
ENV LIBINTL_VER=0.20.2-r0
WORKDIR /

RUN apk update \
    && apk add --no-cache \
       bash="${BASH_VER}" \
       gettext="${GETTEXT_VER}" \
       libintl="${LIBINTL_VER}" \
    && rm -rf /var/cache/apk/*

COPY . /base-chart/
COPY --from=builder /linux-amd64/helm /usr/local/bin/
COPY --from=builder /kubectl /usr/local/bin/
COPY --from=builder /kustomize /usr/local/bin/
COPY --from=builder /ChartInflator /root/.config/kustomize/plugin/kustomize.config.k8s.io/v1/chartinflator/