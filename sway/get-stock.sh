#!/usr/bin/env bash
#
# This script fetches stock price data from the Tiingo API and displays
# the current price and percentage change vs. the previous close.
#
# - It reads the Tiingo API key from an external file for safety.
# - It cycles through a list of tickers stored in an in-script array.
# - It outputs JSON intended for consumption by a status bar/widget.

# ---------------------------------------------------------------------
# Bash Safety Settings
# ---------------------------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------

# Path to the file that contains your Tiingo API key.
# You can change this to the desired file path or pass it in as an argument.
API_KEY_FILE="${1:-.tiingo_api_key}"

# Tickers you want to monitor.
TICKERS=("NVDA" "BRK-A" "SPY")

# Number of seconds over which we rotate through the TICKERS array.
ROTATION_SECONDS=70

# Threshold for "critical" downward movement (in %).
CRITICAL_DOWN_THRESHOLD=-10

# (Optional) Candle interval in minutes; not used by Tiingo in this example,
# but included for completeness.
CHART_INTERVAL=5

# ---------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------

# A function to perform the actual JSON retrieval and basic error-checking.
fetch_json() {
  local url="$1"
  local api_key="$2"
  local response

  # -f (fail), -s (silent), -S (show errors), -L (follow redirects)
  if ! response="$(curl -fsSL \
                     -H "Content-Type: application/json" \
                     -H "Authorization: Token ${api_key}" \
                     "${url}" 2>/dev/null)"; then
    echo "Error: Failed to fetch data from: $url" >&2
    exit 1
  fi

  echo "$response"
}

# ---------------------------------------------------------------------
# Read API Key from File
# ---------------------------------------------------------------------

if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "Error: API key file '$API_KEY_FILE' does not exist." >&2
  exit 1
fi

# Read the entire contents of the file into API_KEY
# (Assumes only one line with the key)
API_KEY="$(<"$API_KEY_FILE")"

# Simple check for an empty file
if [[ -z "$API_KEY" ]]; then
  echo "Error: API key file '$API_KEY_FILE' is empty." >&2
  exit 1
fi

# ---------------------------------------------------------------------
# Main Execution
# ---------------------------------------------------------------------

# 1) Compute the index based on time-based rotation.
ticker_index=$(( $(date +%s) / ROTATION_SECONDS % ${#TICKERS[@]} ))
selected_ticker="${TICKERS[$ticker_index]}"

# 2) Construct Tiingo API URL for the selected ticker.
TIINGO_URL="https://api.tiingo.com/iex/${selected_ticker}"

# 3) Fetch data from Tiingo.
response_json="$(fetch_json "$TIINGO_URL" "$API_KEY")"

# 4) Extract last price and previous close from JSON.
last_price="$(echo "$response_json" | jq -r '.[0].tngoLast')"
prev_close="$(echo "$response_json" | jq -r '.[0].prevClose')"

# 5) Validate the data.
if [[ -z "$last_price" || -z "$prev_close" || "$last_price" == "null" || "$prev_close" == "null" ]]; then
  echo "Error: Missing or invalid data in API response for ticker: $selected_ticker" >&2
  exit 1
fi

# 6) Check for zero previous close to avoid division by zero.
if (( $(echo "$prev_close == 0" | bc -l) )); then
  echo "Error: Previous close is zero for ticker: $selected_ticker (cannot calculate % change)." >&2
  exit 1
fi

# 7) Calculate the percentage change.
price_change_pct="$(echo "scale=2; ($last_price - $prev_close) / $prev_close * 100" | bc -l)"

# 8) Determine the output class based on percentage change.
if (( $(echo "$price_change_pct < 0" | bc -l) )); then
  if (( $(echo "$price_change_pct < $CRITICAL_DOWN_THRESHOLD" | bc -l) )); then
    class="critdown"
  else
    class="down"
  fi
else
  # Example: extra condition if you want another class for
  # a big upward move (e.g., > +5%)
  if (( $(echo "$price_change_pct > 5" | bc -l) )); then
    class="wayup"
  else
    class="up"
  fi
fi

# 9) Output JSON for consumption by a status bar or widget (e.g. waybar, polybar, i3blocks).
echo "{
  \"text\": \"${selected_ticker} \$${last_price} (${price_change_pct}%)\",
  \"tooltip\": \"\",
  \"class\": \"${class}\"
}"
