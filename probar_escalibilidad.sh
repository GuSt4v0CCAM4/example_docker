#!/usr/bin/env bash
# send_1000_random.sh
# Envía 1000 POST a http://IP/api/people
# Reemplaza IP por la IP/host real (ej: 192.168.1.10:8080)

BASE_URL="http://136.114.158.67/api/people"
TOTAL=1000
SUCCESS=0
FAIL=0

# Arrays simples de ejemplo — modifica o añade más nombres/apellidos si quieres
NOMBRES=(Juan Maria Carlos Luis Ana Sofia Lucia Pedro Diego)
APELLIDOS=(Gonzalez Ramirez Perez Lopez Sanchez Diaz Romero Torres Flores)

rand_from_array() {
  local -n arr=$1
  echo "${arr[RANDOM % ${#arr[@]}]}"
}

rand_digits() {
  local len=$1
  local s=""
  for ((i=0;i<len;i++)); do
    s+=$((RANDOM%10))
  done
  echo "$s"
}

for ((i=1;i<=TOTAL;i++)); do
  nombre=$(rand_from_array NOMBRES)
  apellido=$(rand_from_array APELLIDOS)
  telefono="$(rand_digits 9)"   # 9 dígitos — ajusta según país
  dni="$(rand_digits 8)"       # 8 dígitos — ajusta según necesidad

  # JSON — el campo id NO se envía porque lo genera el servidor
  json=$(cat <<EOF
{
  "nombre": "${nombre}",
  "apellido": "${apellido}",
  "telefono": "${telefono}",
  "dni": "${dni}"
}
EOF
)

  # Enviar POST con curl
  # -s para silencioso, -w '%{http_code}' para obtener código HTTP
  resp=$(curl -s -o /tmp/curl_out.txt -w "%{http_code}" -X POST "${BASE_URL}" \
    -H "Content-Type: application/json" \
    -d "${json}")

  if [[ "$resp" =~ ^2 ]]; then
    ((SUCCESS++))
  else
    ((FAIL++))
    echo "Error (HTTP $resp) en registro $i -> ${json}"
    echo "Respuesta del servidor:"
    cat /tmp/curl_out.txt
  fi

  # opcional: breve pausa para no saturar el servidor
  # sleep 0.01
done

echo "Envío finalizado. OK: $SUCCESS, Fallidos: $FAIL"
