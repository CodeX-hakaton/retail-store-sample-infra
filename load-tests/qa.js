import http from 'k6/http';
import { check, sleep } from 'k6';

const targetUrl = __ENV.TARGET_URL || 'https://qa.codex-devops.pp.ua';
const loadTestSource = __ENV.LOAD_TEST_SOURCE || 'circleci-k6';
const loadTestRunId =
  __ENV.LOAD_TEST_RUN_ID || __ENV.CIRCLE_WORKFLOW_ID || 'local-run';

function buildHeaders() {
  const headers = {
    'X-Load-Test-Source': loadTestSource,
    'X-Load-Test-Run-Id': loadTestRunId,
  };

  if (__ENV.LOAD_TEST_HEADER_NAME && __ENV.LOAD_TEST_HEADER_VALUE) {
    headers[__ENV.LOAD_TEST_HEADER_NAME] = __ENV.LOAD_TEST_HEADER_VALUE;
  }

  if (__ENV.CF_ACCESS_CLIENT_ID) {
    headers['CF-Access-Client-Id'] = __ENV.CF_ACCESS_CLIENT_ID;
  }

  if (__ENV.CF_ACCESS_CLIENT_SECRET) {
    headers['CF-Access-Client-Secret'] = __ENV.CF_ACCESS_CLIENT_SECRET;
  }

  return headers;
}

function metricValue(data, metricName, statName) {
  if (!data.metrics[metricName] || !data.metrics[metricName].values) {
    return null;
  }

  return data.metrics[metricName].values[statName];
}

export const options = {
  vus: Number(__ENV.K6_VUS || 10),
  duration: __ENV.K6_DURATION || '30s',
  summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'max'],
  thresholds: {
    http_req_failed: ['rate<0.05'],
    http_req_duration: ['avg<1000', 'p(95)<2000'],
    checks: ['rate>0.95'],
  },
};

export default function () {
  const response = http.get(targetUrl, {
    headers: buildHeaders(),
    tags: {
      environment: __ENV.TARGET_ENV || 'qa',
      source: loadTestSource,
      suite: 'qa-pr-open-load-test',
    },
  });

  check(response, {
    qa_endpoint_is_up: (res) => res.status >= 200 && res.status < 500,
  });

  sleep(Number(__ENV.K6_SLEEP || 1));
}

export function handleSummary(data) {
  const avgLatencyMs = metricValue(data, 'http_req_duration', 'avg');
  const p95LatencyMs = metricValue(data, 'http_req_duration', 'p(95)');
  const failedRate = metricValue(data, 'http_req_failed', 'rate');
  const checkRate = metricValue(data, 'checks', 'rate');
  const requestCount = metricValue(data, 'http_reqs', 'count');

  let endpointStatus = 'unknown';
  if (checkRate !== null) {
    endpointStatus = checkRate >= 0.95 ? 'up' : 'down_or_degraded';
  }

  const summaryLines = [
    `target_url=${targetUrl}`,
    `status=${endpointStatus}`,
    `avg_latency_ms=${avgLatencyMs === null ? 'n/a' : avgLatencyMs.toFixed(2)}`,
    `p95_latency_ms=${p95LatencyMs === null ? 'n/a' : p95LatencyMs.toFixed(2)}`,
    `http_failed_rate=${failedRate === null ? 'n/a' : failedRate.toFixed(4)}`,
    `check_pass_rate=${checkRate === null ? 'n/a' : checkRate.toFixed(4)}`,
    `request_count=${requestCount === null ? 'n/a' : requestCount}`,
    `load_test_source=${loadTestSource}`,
    `load_test_run_id=${loadTestRunId}`,
  ];

  return {
    'load-tests/results/summary.json': JSON.stringify(data, null, 2),
    'load-tests/results/summary.txt': `${summaryLines.join('\n')}\n`,
  };
}
