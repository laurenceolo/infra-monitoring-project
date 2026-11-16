set -uo pipefail

if [[ $# -ne 1 || -z "${1:-}" ]]; then
  echo "Использование: $0 <URL>" >&2
  exit 1
fi

url="$1"

if http_code=$(curl -sS -L -o /dev/null -w '%{http_code}' \
  --connect-timeout 5 --max-time 20 "$url"); then
  if [[ "$http_code" == "200" ]]; then
    echo "API доступен"
    exit 0
  fi
fi

echo "API недоступен, код ответа: ${http_code:-000}"
exit 1
