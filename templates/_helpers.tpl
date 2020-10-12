{{/*
Expand the name of the chart.
*/}}
{{- define "baseChart.name" -}}
{{- default .Chart.Name .Values.fullNameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "baseChart.fullName" -}}
{{- if .Values.fullNameOverride }}
{{- .Values.fullNameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{- define "baseChart.releaseName" -}}
{{ .Release.Name }}
{{- end}}
{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "baseChart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "baseChart.labels" -}}
{{ include "baseChart.selectorLabels" . }}
{{- if .Values.image.appVersion }}
{{ include "baseChart.labels.version" . }} : {{ .Values.image.appVersion | quote }}
{{- end }}
{{ include "baseChart.labels.managedBy" . }} : {{ .Release.Service }}
{{- end }}

{{- define "baseChart.labels.appName" -}}
app
{{- end }}

{{- define "baseChart.labels.version" -}}
version
{{- end }}

{{- define "baseChart.labels.managedBy" -}}
app.kubernetes.io/managed-by
{{- end }}


{{/*
Selector labels
*/}}
{{- define "baseChart.selectorLabels" -}}
{{ include "baseChart.labels.appName" . }} : {{ include "baseChart.fullName" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "baseChart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "baseChart.fullName" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Create the name of the podAntiAffinity to use
*/}}
{{- define "baseChart.podAntiAffinity" -}}
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: {{ include "baseChart.labels.appName" . }}
                operator: In
                values:
                - {{ include "baseChart.fullName" . }}
              - key: {{ include "baseChart.labels.version" . }}
                operator: In
                values:
                  - {{ .Values.image.appVersion | quote }}
          topologyKey: kubernetes.io/hostname
        weight: 100
{{- end }}
