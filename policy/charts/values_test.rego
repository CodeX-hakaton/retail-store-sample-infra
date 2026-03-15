package main

test_chart_policy_accepts_current_defaults {
  results := {msg |
    deny[msg] with input as {
      "service": {
        "type": "ClusterIP",
      },
      "securityContext": {
        "runAsNonRoot": true,
        "readOnlyRootFilesystem": true,
      },
    }
  }
  count(results) == 0
}

test_chart_policy_rejects_non_clusterip_service {
  some msg
  deny[msg] with input as {
    "service": {
      "type": "LoadBalancer",
    },
    "securityContext": {
      "runAsNonRoot": true,
      "readOnlyRootFilesystem": true,
    },
  }
  msg == "chart default service.type must be ClusterIP"
}

test_chart_policy_rejects_missing_non_root_flag {
  some msg
  deny[msg] with input as {
    "service": {
      "type": "ClusterIP",
    },
    "securityContext": {
      "readOnlyRootFilesystem": true,
    },
  }
  msg == "securityContext.runAsNonRoot must be true"
}
