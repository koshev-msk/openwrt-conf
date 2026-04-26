#!/bin/sh

# Определяем размер overlay
if [ -d /overlay ]; then
  overlay_info=$(df -k /overlay 2>/dev/null | tail -1)
elif mount | grep -q "on /overlay type"; then
  overlay_info=$(df -k /overlay 2>/dev/null | tail -1)
else
  overlay_info=$(df -k / 2>/dev/null | tail -1)
fi

overlay_total=$(echo "$overlay_info" | awk '{print $2}')  # в килобайтах
overlay_used=$(echo "$overlay_info" | awk '{print $3}')
overlay_available=$(echo "$overlay_info" | awk '{print $4}')
overlay_use_percent=$(echo "$overlay_info" | awk '{print $5}' | tr -d '%')

# Время прошивки
FLASH_TIME="$(awk '
$1 == "Installed-Time:" && ($2 < OLDEST || OLDEST=="") {
  OLDEST=$2
}
END {
  print OLDEST
}
' /usr/lib/opkg/status)"

temp_file="/tmp/user_packages.$$"

echo "📊 Анализ установленных пакетов"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Проверяем overlay
if [ -n "$overlay_total" ]; then
  echo "Overlay раздел:"
  echo "  ├─ Всего:    $(awk "BEGIN {printf \"%.2f MB\", $overlay_total/1024}")"
  echo "  ├─ Использовано: $(awk "BEGIN {printf \"%.2f MB\", $overlay_used/1024}") ($overlay_use_percent%)"
  echo "  └─ Свободно: $(awk "BEGIN {printf \"%.2f MB\", $overlay_available/1024}")"
  echo ""
else
  echo "⚠️  Не удалось определить размер overlay раздела"
  overlay_available=0
fi

# Собираем информацию о пакетах
awk -v FT="$FLASH_TIME" '
function format_size_kb(bytes) {
  kb = bytes / 1024
  if(kb >= 1024) {
    return sprintf("%.2f MB", kb / 1024)
  } else {
    return sprintf("%.2f KB", kb)
  }
}

BEGIN {
  RS=""
  FS="\n"
}
{
  pkg_name=""
  is_user=0
  pkg_time=""
  pkg_version=""
  
  for(i=1; i<=NF; i++) {
    if($i ~ /^Package: /) {
      pkg_name = substr($i, 10)
      gsub(/^[ \t]+|[ \t]+$/, "", pkg_name)
    }
    if($i ~ /^Version: /) {
      pkg_version = substr($i, 9)
      gsub(/^[ \t]+|[ \t]+$/, "", pkg_version)
    }
    if($i ~ /^Status: .* user/) {
      is_user=1
    }
    if($i ~ /^Installed-Time: /) {
      pkg_time = substr($i, 17)
      gsub(/^[ \t]+|[ \t]+$/, "", pkg_time)
    }
  }
  
  if(is_user && pkg_time != FT && pkg_name != "") {
    control_file = "/usr/lib/opkg/info/" pkg_name ".control"
    size_bytes = 0
    
    cmd = "cat " control_file " 2>/dev/null | grep \"^Installed-Size:\" | head -1"
    while((cmd | getline line) > 0) {
      split(line, arr, ":")
      size_bytes = int(arr[2])
      gsub(/^[ \t]+|[ \t]+$/, "", size_bytes)
    }
    close(cmd)
    
    printf "%d|%s|%s|%s\n", size_bytes, pkg_name, pkg_version, pkg_time
  }
}
' /usr/lib/opkg/status | sort -t'|' -k1 -rn > "$temp_file"

# Выводим пакеты
count=0
total_bytes=0

while IFS='|' read size_bytes pkg_name pkg_version pkg_time; do
  count=$((count + 1))
  total_bytes=$((total_bytes + size_bytes))
  
  size_kb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1024}")
  overlay_available_kb=${overlay_available:-0}
  
  # Вычисляем процент от свободного места в overlay
  if [ "$overlay_available_kb" -gt 0 ] && [ "$overlay_available_kb" -gt 0 ]; then
    percent=$(awk "BEGIN {printf \"%.2f\", ($size_kb / $overlay_available_kb) * 100}")
  else
    percent="N/A"
  fi
  
  # Форматируем размер для вывода
  if [ $size_bytes -ge 1048576 ]; then
    size_formatted=$(awk "BEGIN {printf \"%.2f MB\", $size_bytes/1048576}")
  else
    size_formatted=$(awk "BEGIN {printf \"%.2f KB\", $size_bytes/1024}")
  fi
  
  echo "┌─ $pkg_name"
  echo "│ Версия: $pkg_version"
  echo "│ Установлен: $(date -d "@$pkg_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$pkg_time")"
  echo "│ Размер: $size_formatted"
  
  if [ "$percent" != "N/A" ] && [ "$percent" != "0.00" ]; then
    echo "│ Занято от свободного места: ${percent}%"
    
    # Визуальный бар
    bar_width=40
    filled=$(awk "BEGIN {printf \"%.0f\", ($size_kb / $overlay_available_kb) * $bar_width}")
    [ $filled -lt 0 ] && filled=0
    [ $filled -gt $bar_width ] && filled=$bar_width
    
    bar=""
    for i in $(seq 1 $filled); do bar="${bar}█"; done
    for i in $(seq $filled $((bar_width - 1))); do bar="${bar}░"; done
    
    echo "│ [${bar}]"
  elif [ "$percent" == "0.00" ] && [ $size_bytes -gt 0 ]; then
    echo "│ Доля в overlay: < 0.01%"
  fi
  
  echo "└─────────────────────────────────────────────────────"
  echo ""
done < "$temp_file"

# Итоговая статистика
echo "═══════════════════════════════════════════════════════════"
echo "📈 ИТОГО:"
echo "  ├─ Пользовательских пакетов: $count"
echo "  ├─ Общий размер: $(awk "BEGIN {printf \"%.2f MB\", $total_bytes/1048576}")"

if [ "$overlay_available_kb" -gt 0 ] && [ $overlay_available_kb -gt 0 ]; then
  total_percent=$(awk "BEGIN {printf \"%.2f\", ($total_bytes/1024 / $overlay_available_kb) * 100}")
  echo "  └─ Занимают от свободного места в overlay: ${total_percent}%"
fi

echo "═══════════════════════════════════════════════════════════"

# Предупреждение, если пакеты занимают много места
if [ -n "$total_percent" ] && [ $(echo "$total_percent > 80" | bc) -eq 1 ]; then
  echo ""
  echo "⚠️  ВНИМАНИЕ: Ваши пакеты занимают более 80% свободного места в overlay!"
  echo "   Рекомендуется очистить overlay или увеличить раздел."
fi

rm -f "$temp_file"
