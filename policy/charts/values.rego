package main

deny[msg] {
  service := object.get(input, "service", {})
  object.get(service, "type", "") != "ClusterIP"
  msg := "chart default service.type must be ClusterIP"
}

deny[msg] {
  security_context := object.get(input, "securityContext", {})
  object.get(security_context, "runAsNonRoot", false) != true
  msg := "securityContext.runAsNonRoot must be true"
}

deny[msg] {
  security_context := object.get(input, "securityContext", {})
  object.get(security_context, "readOnlyRootFilesystem", false) != true
  msg := "securityContext.readOnlyRootFilesystem must be true"
}
