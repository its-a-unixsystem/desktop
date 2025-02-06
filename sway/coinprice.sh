#!/usr/bin/env bash
set x
#
# This script fetches cryptocurrency data from Kraken and displays
# current price and percentage changes based on OHLC data from yesterday.

# ---------------------------------------------------------------------
# Bash Safety Settings
# ---------------------------------------------------------------------
# -e : Exit immediately on command error.
# -u : Treat unset variables as an error.
# -o pipefail : Return non-zero exit code if any command in a pipeline fails.
# -E : Ensure that ERR traps get inherited by functions, command substitutions, and subshells.
set -Eeuo pipefail

# We also set IFS to a safe default to avoid unexpected word splitting:
IFS=$'\n\t'

# ---------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------
TRADE_PAIRS=("DOTEUR" "TBTCEUR" "XETHZEUR")
TRADE_SIGNS=("" "" "⟠")

# Number of seconds over which we cycle through TRADE_PAIRS and TRADE_SIGNS.
ROTATION_SECONDS=10

# Candle interval in minutes (e.g., 5 = 5-minute candles).
CHART_INTERVAL=5

# Kraken public API base URL.
KRAKEN_API="https://api.kraken.com/0/public"

# Threshold for "critical" downward movement (in %).
CRITICAL_DOWN_THRESHOLD=-10

# 24 hours in seconds
YESTERDAY_OFFSET=86400

# ---------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------

# Fetch data from URL, returning JSON on success, or exiting with an error on failure.
fetch_json() {
  local url="$1"
  local response

  # Use -f (fail), -s (silent), -S (show errors), -L (follow redirects)
  if ! response="$(curl -fsSL -H 'Accept: application/json' "$url" 2>/dev/null)"; then
    echo "Error: Failed to fetch data from: $url" >&2
    exit 1
  fi

  # Optional: You may want to validate that response is valid JSON, but
  # at least we know `jq` will fail later if it's not.
  echo "$response"
}

# Calculate a percentage change given old and new values.
# Returns "NA" if old == 0, otherwise prints a formatted float.
calculate_change_percentage() {
  local old_value="$1"
  local new_value="$2"

  awk -v old="$old_value" -v new="$new_value" '
    BEGIN {
      if (old == 0) {
        print "NA"
      } else {
        printf "%.2f", ((new - old) / old) * 100
      }
    }
  '
}

# Safely format a float to two decimal places. If it's "NA", pass it through.
safe_format_float() {
  local val="$1"

  if [[ "$val" == "NA" ]]; then
    echo "NA"
  else
    printf "%4.2f" "$val"
  fi
}

# ---------------------------------------------------------------------
# Main Execution
# ---------------------------------------------------------------------

# 1. Determine which pair/sign to use based on time-based rotation.
pair_index=$(( $(date +%s) / ROTATION_SECONDS % ${#TRADE_PAIRS[@]} ))
selected_pair="${TRADE_PAIRS[$pair_index]}"
selected_sign="${TRADE_SIGNS[$pair_index]}"

# 2. Calculate the timestamp for "yesterday."
yesterday_timestamp=$(( $(date +%s) - YESTERDAY_OFFSET ))

# 3. Construct API endpoints for OHLC and Ticker.
OHLC_URL="${KRAKEN_API}/OHLC?pair=${selected_pair}&interval=${CHART_INTERVAL}"
TICKER_URL="${KRAKEN_API}/Ticker"

# 4. Fetch data from Kraken.
ohlc_json="$(fetch_json "$OHLC_URL")"
ticker_json="$(fetch_json "$TICKER_URL")"

# 5. Extract the current price (volume-weighted average for 'today').
current_value="$(
  echo "$ticker_json" \
    | jq -r ".result.\"${selected_pair}\".p[0] // \"\""
)"

if [[ -z "$current_value" ]]; then
  echo "Error: Could not retrieve current price for ${selected_pair}." >&2
  exit 1
fi

# 6. Retrieve the last candle from or before 'yesterday'.
old_candle="$(
  echo "$ohlc_json" \
    | jq -c "
      .result.\"${selected_pair}\"
      | map(select(.[0] <= ${yesterday_timestamp}))
      | max_by(.[0])"
)"

# If there's no matching candle, old_candle might be 'null'.
if [[ "$old_candle" == "null" || -z "$old_candle" ]]; then
  # If you want to exit gracefully or show "NA" for old data, do so here.
  # We'll exit for clarity:
  echo "Warning: No candle found for ${selected_pair} prior to $yesterday_timestamp." >&2
  # You can either exit or default old_vwap to current_value:
  # exit 1
  old_vwap="$current_value"
else
  # Candle array is [time, open, high, low, close, vwap, volume, count].
  # 'close' is at index 4.
  old_vwap="$(echo "$old_candle" | jq -r '.[4] // ""')"
fi

# Check that we have a valid old_vwap
if [[ -z "$old_vwap" ]]; then
  old_vwap="$current_value"
fi

# 7. Calculate the percentage change.
change_percentage="$(calculate_change_percentage "$old_vwap" "$current_value")"

# 8. Format numeric outputs to two decimals if they are not "NA".
change_percentage="$(safe_format_float "$change_percentage")"
current_value="$(safe_format_float "$current_value")"

# 9. Determine output class based on percentage change.
#    If change_percentage is NA or otherwise not numeric, we default to "up."
status_class="up"

# We'll only parse numeric if it's not "NA".
if [[ "$change_percentage" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
  # It's numeric, so we can compare using bc
  if (( $(echo "$change_percentage < 0" | bc -l) )); then
    if (( $(echo "$change_percentage < $CRITICAL_DOWN_THRESHOLD" | bc -l) )); then
      status_class="critdown"
    else
      status_class="down"
    fi
  else
    status_class="up"
  fi
fi

# 10. Output JSON for consumption by a status bar or widget.
#     (e.g. waybar, polybar, i3blocks, etc.)
echo "{  \"text\": \"${selected_sign} €${current_value} (${change_percentage}%)\",  \"tooltip\": \"€${current_value} (${change_percentage}%)\",  \"class\": \"${status_class}\" }"
