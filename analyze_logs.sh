set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log_file="${1:-$script_dir/access.log}"

if [[ $# -eq 0 ]]; then
  : > "$log_file"
  for ((i = 0; i < 360; i++)); do
    case $((i % 10)) in
      0|1|2|3) ip='192.168.1.10' ;;
      4|5|6)   ip='10.0.0.5' ;;
      7|8)     ip='172.16.0.12' ;;
      *)       ip='203.0.113.8' ;;
    esac
    case $((i % 5)) in
      0) method='GET';  endpoint='/api/users' ;;
      1) method='POST'; endpoint='/api/login' ;;
      2) method='GET';  endpoint='/health' ;;
      3) method='PUT';  endpoint='/api/profile' ;;
      *) method='DELETE'; endpoint='/api/orders' ;;
    esac
    case $((i % 7)) in
      0) status=200 ;;
      1) status=201 ;;
      2) status=200 ;;
      3) status=404 ;;
      4) status=500 ;;
      5) status=401 ;;
      *) status=503 ;;
    esac
    printf '%s - - [15/Aug/2026:10:%02d:%02d +0000] "%s %s HTTP/1.1" %s 123\n' \
      "$ip" "$((i / 60))" "$((i % 60))" "$method" "$endpoint" "$status" >> "$log_file"
  done
  printf 'Создан тестовый журнал: %s (360 строк)\n' "$log_file"
fi

if [[ ! -f "$log_file" ]]; then
  echo "Ошибка: файл логов не найден: $log_file" >&2
  exit 1
fi

requests="$(wc -l < "$log_file" | awk '{print $1}')"
top_ips="$(grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}[[:space:]]' "$log_file" \
  | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 3 || true)"

errors="$(awk -F '"' 'NF >= 3 {
  split($3, fields, " ");
  for (i in fields) {
    if (fields[i] ~ /^[45][0-9][0-9]$/) {errors++; break}
  }
} END {print errors+0}' "$log_file")"

printf '\n=== Анализ HTTP-логов ===\n'
printf 'Всего запросов: %s\n' "$requests"
printf '\nТоп-3 IP-адреса (количество запросов — адрес):\n'
if [[ -n "$top_ips" ]]; then
  printf '%s\n' "$top_ips" | awk '{printf "%s — %s\n", $1, $2}'
else
  echo 'IP-адреса не найдены'
fi
printf '\nЗапросов с кодами 4xx и 5xx: %s\n' "$errors"
