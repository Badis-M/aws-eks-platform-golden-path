{{- define "incident-api.name" -}}
incident-api
{{- end }}

{{- define "incident-api.fullname" -}}
{{ .Release.Name }}-{{ include "incident-api.name" . }}
{{- end }}

{{- define "incident-api.labels" -}}
app.kubernetes.io/name: {{ include "incident-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
