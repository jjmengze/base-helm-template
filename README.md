# service-base-chart

測試 `values.yaml`  透過 base chart 與 kustomize 渲染結果是否正確，首先我們需要下載 base chart tool box 的 docker image，指令如下所示。
```bash
docker run -ti --rm registry-fortress.fareastone.com.tw/prod-lafite/service-base-chart:1.0.10 bash
```

接著建立 kustomize 需要的目錄結構，並且將 container image 內置的 base chart 移動到 base 下。
```bash
mkdir -p /base
mkdir -p /overlays/ocp
mkdir -p /overlays/k8s
mv /base-chart /base
```

有了這些目錄結構我們可以建立 kustomize 基礎所需要的檔案

1. 先建立基礎樣板的 `kustomization.yaml`

```bash
cat <<EOF > /base/kustomization.yaml
generators:
  - chartref.yaml
EOF
```

2. `chartref.yaml` 裡面會描述這個 kustomize 會用到哪一個 helm chart 以及待會要選染 chart 的 `value.yaml` 要使用哪一個。
```bash
cat <<EOF > /base/chartref.yaml
apiVersion: kustomize.config.k8s.io/v1
kind: ChartInflator
metadata:
  name: example-nginx
  namespace: example-nginx
chartHome: base-chart
releaseName: example
values: ./values.yaml
EOF
```

3. 撰寫 values.yaml 提供 chart 渲染，這個values.yaml 非常的簡單。

定義了他要使用的資源型態（`deployment`）、副本數(`1`)、使用的container image(`nginx:`1.19.3-alpine`)、資源限制、以及存活判斷的機制。
例外服務透過ClusterIP對叢集內部提供80的tcp服務。

```bash
cat <<EOF > /base/values.yaml
kind: deployment

replicaCount: 1

restartPolicy: Always

image:
  repository: "nginx"
  pullPolicy: IfNotPresent
  appVersion: 1.19.3-alpine

# Required: It's necessary for users to assign resource usage.
resources:
  limits:
    cpu: 500m
    memory: 200Mi
  requests:
    cpu: 200m
    memory: 100Mi

# Users can customize the container requirement below.
container:
  livenessProbe:
    httpGet:
      path: /
      port: 80
    initialDelaySeconds: 30
    periodSeconds: 80
    timeoutSeconds: 5
  readinessProbe:
    httpGet:
      path: /
      port: 80
    initialDelaySeconds: 30
    periodSeconds: 80
    timeoutSeconds: 5

nameOverride: example-nginx

service:
  type: ClusterIP
  ports:
    # Customize the port and protocol.
    - port: 80
      targetPort: 80
      protocol: TCP
      # Customize the name if needed, default is "<group-name>-<project-name>"
      name: http

EOF
```

當前目錄結構會長得像下圖所示。
```bash
tree .
.
├── base
│ ├── base-chart
│ │ ├── Chart.yaml
│ │ ├── Dockerfile
│ │ ├── README.md
│ ├── chartref.yaml
│ ├── kustomization.yaml
│ └── values.yaml
├── overlays
│ ├── ocp
│ └── k8s
...
```

我們在 base 的資料夾內裡面使用 kustomize 指令將values.yaml 透過 kustomize 與 base-chart 進行渲染，指令如下所示。


需要檢查輸出的結果是否跟要部署的yaml是一樣的，若是有不一樣的地方可以找devops team的成員處理。

```bash
kustomize build --enable_alpha_plugins .
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/managed-by: Helm
    name: example-example-nginx
  name: example-example-nginx
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: example-example-nginx
  type: ClusterIP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: example-example-nginx
    app.kubernetes.io/managed-by: Helm
    version: 1-19-3-alpine
  name: example-example-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: example-example-nginx
  template:
    metadata:
      labels:
        app: example-example-nginx
        version: 1-19-3-alpine
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - example-example-nginx
                - key: version
                  operator: In
                  values:
                  - 1-19-3-alpine
              topologyKey: kubernetes.io/hostname
            weight: 100
      containers:
      - envFrom: null
        image: nginx:1.19.3-alpine
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 80
          timeoutSeconds: 5
        name: example-example-nginx
        ports: null
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 80
          timeoutSeconds: 5
        resources:
          limits:
            cpu: 500m
            memory: 200Mi
          requests:
            cpu: 200m
            memory: 100Mi
      nodeSelector:
        node-role.kubernetes.io/compute: ""
      restartPolicy: Always
      serviceAccountName: default
```

## example
If you needs to add some customized resources. Please read the example in the example folder.

**patches** <br>
Patches add or override fields on resources.<br>
**resources** <br>
Resources to include. Each entry in this list must be a path to a file, or a path (or URL) referring to another. <br>
**configMapGenerator** <br>
Generate ConfigMap resources. <br>

We would now set up our folder structure like this:

```sh
.
└── deployments
    ├── base # Shared base resources
    │   ├── chartref.yaml
    │   ├── kustomization.yaml
    │   └── values.yaml
    ├── deploy.sh  # Deploy scripts
    ├── overlays
    │   ├── k8s  # Same folder structure with ocp
    │       └── ...
    │   └── ocp
    │       ├── configMapGenetor
    │       │   └── files
    │       │       ├── file1
    │       │       └── ...
    │       ├── kustomization.yaml
    │       ├── patches  # Apply different customizations to Resources
    │       │   └── patch.yaml
    │       ├── project.yaml  # Define OCP project
    │       └── resources  # Specify resources (The sub folders are classified by Kind)
    │           ├── configmaps  # Put ConfigMap resources
    │           │   ├── env.yaml  # Named according to the purpose (as resource name)
    │           │   └── ...
    │           │── secrets
    │           │   ├── cert.yaml
    │           │   ├── env.yaml
    │           │   └── ...
    │           └── ...
    └── var_replace.sh  # Replace the environment value to real value
```

More rules and examples, please refer to [wiki](https://fortress.fareastone.com.tw/prod-lafite/service-base-chart/-/wikis/deployment-naming-discipline).

- Reference: [KUSTOMIZE API Reference](https://kubernetes-sigs.github.io/kustomize/api-reference/kustomization/)

