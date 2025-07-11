#!/bin/bash

# -------------------------------------------------------------------
# Docker Container Port Export Script with Interactive Prompt
# -------------------------------------------------------------------
# Supports manual selection of:
# - Markdown
# - CSV
# - Homarr widget HTML
# - Homer widget HTML
# - All formats
# -------------------------------------------------------------------

# Prompt user interactively if no argument is passed
if [[ -z "$1" ]]; then
  clear
  echo "Docker Container Export Menu"
  echo "-------------------------------------"
  echo "1) Export to Markdown"
  echo "2) Export to CSV"
  echo "3) Export to Homarr widget"
  echo "4) Export to Homer widget"
  echo "5) Export to ALL formats"
  echo "6) Quit"
  read -rp $'\nSelect an option [1-6]: ' choice

  case $choice in
    1) MODE="markdown";;
    2) MODE="csv";;
    3) MODE="homarr";;
    4) MODE="homer";;
    5) MODE="all";;
    6) echo "Exiting."; exit 0;;
    *) echo "Invalid choice"; exit 1;;
  esac
else
  case "$1" in
    --markdown) MODE="markdown";;
    --csv) MODE="csv";;
    --homarr) MODE="homarr";;
    --homer) MODE="homer";;
    --all) MODE="all";;
    *) echo "Invalid argument: $1"; exit 1;;
  esac
fi

# Set timestamp and export directory
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
EXPORT_DIR="./docker_exports"
LATEST_TAG="latest"
mkdir -p "$EXPORT_DIR"

# Get container data
container_data=$(docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}' | while IFS='|' read -r name image status; do
  ports=$(docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}} -> {{(index $conf 0).HostPort}}, {{end}}{{end}}' "$name" | sed 's/, $//')
  echo "$name|$image|$status|$ports"
done | sort)

if [ -z "$container_data" ]; then
  echo "No container data found. Make sure Docker is running and containers exist."
  exit 1
fi

# Markdown Export
if [[ "$MODE" == "markdown" || "$MODE" == "all" ]]; then
  MD_FILE="$EXPORT_DIR/docker_ports_$TIMESTAMP.md"
  {
    echo "# Docker Container Ports Export"
    echo "_Generated: $TIMESTAMP_"
    echo ""
    echo "| Container | Image | Status | Ports |"
    echo "|-----------|--------|--------|--------|"
    echo "$container_data" | while IFS='|' read -r name image status ports; do
      echo "| $name | $image | $status | $ports |"
    done
  } > "$MD_FILE"
  cp "$MD_FILE" "$EXPORT_DIR/docker_ports_$LATEST_TAG.md"
  echo "Markdown exported to: $MD_FILE"
fi

# CSV Export
if [[ "$MODE" == "csv" || "$MODE" == "all" ]]; then
  CSV_FILE="$EXPORT_DIR/docker_ports_$TIMESTAMP.csv"
  {
    echo "Container,Image,Status,Ports"
    echo "$container_data" | while IFS='|' read -r name image status ports; do
      echo "$name,$image,$status,$ports"
    done
  } > "$CSV_FILE"
  cp "$CSV_FILE" "$EXPORT_DIR/docker_ports_$LATEST_TAG.csv"
  echo "CSV exported to: $CSV_FILE"
fi

# Homarr Widget HTML
if [[ "$MODE" == "homarr" || "$MODE" == "all" ]]; then
  HOMARR_FILE="$EXPORT_DIR/homarr_ports_widget_$TIMESTAMP.html"
  {
    echo "<!-- Homarr Widget HTML: Docker Container Ports -->"
    echo "<html><head><meta charset=\"UTF-8\"><style>table{width:100%;border-collapse:collapse;}th,td{border:1px solid #ccc;padding:8px;}th{background:#eee;}body{font-family:sans-serif;font-size:14px;}</style></head><body>"
    echo "<h3>Docker Containers ($TIMESTAMP)</h3>"
    echo "<table><thead><tr><th>Container</th><th>Image</th><th>Status</th><th>Ports</th></tr></thead><tbody>"
    echo "$container_data" | while IFS='|' read -r name image status ports; do
      echo "<tr><td>$name</td><td>$image</td><td>$status</td><td>$ports</td></tr>"
    done
    echo "</tbody></table></body></html>"
  } > "$HOMARR_FILE"
  cp "$HOMARR_FILE" "$EXPORT_DIR/homarr_ports_widget_$LATEST_TAG.html"
  echo "Homarr widget HTML exported to: $HOMARR_FILE"
fi

# Homer Widget HTML
if [[ "$MODE" == "homer" || "$MODE" == "all" ]]; then
  HOMER_FILE="$EXPORT_DIR/homer_ports_widget_$TIMESTAMP.html"
  cp "$EXPORT_DIR/homarr_ports_widget_$TIMESTAMP.html" "$HOMER_FILE"
  cp "$HOMER_FILE" "$EXPORT_DIR/homer_ports_widget_$LATEST_TAG.html"
  echo "Homer widget HTML exported to: $HOMER_FILE"
fi

exit 0
