#!/bin/bash

# -------------------------------------------------------------------
# Docker Container Port Export Script
# -------------------------------------------------------------------
# Generates exports of running and stopped Docker containers with:
# - Markdown table
# - CSV
# - Homarr-compatible HTML widget
# - Homer-compatible HTML widget
# Exports to ./docker_exports/
# -------------------------------------------------------------------

# Set timestamp and export directory
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
EXPORT_DIR="./docker_exports"
LATEST_TAG="latest"

# Ensure export directory exists
mkdir -p "$EXPORT_DIR"

# Get container data (name, image, status, ports)
container_data=$(docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}' | while IFS='|' read -r name image status; do
  ports=$(docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}} -> {{(index $conf 0).HostPort}}, {{end}}{{end}}' "$name" | sed 's/, $//')
  echo "$name|$image|$status|$ports"
done | sort)

# Check if data is empty
if [ -z "$container_data" ]; then
  echo "No container data found. Make sure Docker is running and containers exist."
  exit 1
fi

# Output files
MD_FILE="$EXPORT_DIR/docker_ports_$TIMESTAMP.md"
CSV_FILE="$EXPORT_DIR/docker_ports_$TIMESTAMP.csv"
HOMARR_FILE="$EXPORT_DIR/homarr_ports_widget_$TIMESTAMP.html"
HOMER_FILE="$EXPORT_DIR/homer_ports_widget_$TIMESTAMP.html"

# Markdown Export
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

# CSV Export
{
  echo "Container,Image,Status,Ports"
  echo "$container_data" | while IFS='|' read -r name image status ports; do
    echo "$name,$image,$status,$ports"
  done
} > "$CSV_FILE"
cp "$CSV_FILE" "$EXPORT_DIR/docker_ports_$LATEST_TAG.csv"

# Homarr HTML Widget
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

# Homer Widget HTML (same structure for compatibility)
cp "$HOMARR_FILE" "$HOMER_FILE"
cp "$HOMER_FILE" "$EXPORT_DIR/homer_ports_widget_$LATEST_TAG.html"

# Completion message
echo "✅ Docker container data exported to: $EXPORT_DIR"
echo " - Markdown: $MD_FILE"
echo " - CSV: $CSV_FILE"
echo " - Homarr widget: $HOMARR_FILE"
echo " - Homer widget: $HOMER_FILE"

# -------------------------------------------------------------------
# Optional Add-on Ideas (ask before implementing):
# -------------------------------------------------------------------
# 1. Add systemd timer or cronjob for automated exports
# 2. Add symlink index.html to latest exports for easy dashboard embed
# 3. Add Discord or email notifications
# 4. Add stats (total containers, uptime summary)
# 5. Add service restart or prune toggle
