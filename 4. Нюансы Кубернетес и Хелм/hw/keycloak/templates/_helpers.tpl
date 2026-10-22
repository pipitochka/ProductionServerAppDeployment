{{- define "keycloak.name" -}}
{{- .Release.Name | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{- define "keycloak.labels" -}}
app.kubernetes.io/name: keycloak
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{- define "keycloak.credentials" -}}
{{- default (printf "%s-credentials" (include "keycloak.name" .)) .Values.auth.existingSecret -}}
{{- end -}}

{{- define "keycloak.tls" -}}
{{- default (printf "%s-tls" (include "keycloak.name" .)) .Values.tls.existingSecret -}}
{{- end -}}
