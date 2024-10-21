#!/usr/bin/env nix-shell
#!nix-shell -i bash --packages poppler_utils

sendToLLM() {
  curl https://api.together.xyz/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOGETHER_API_KEY" \
    --data "$1"
}

mkRequestJSON() {
  USERINPUT=$(echo "$1" | jq -s -R '.')
  BASEREQ=$2
  SCHEMA=$(cat "$3")
  SYSTEM=$(cat "$4")

  jq --arg sys "$SYSTEM" --arg txt "$USERINPUT" --argjson schema "$SCHEMA" \
    '.response_format.schema = $schema | .messages[0].content = $sys | .messages[1].content = $txt' "$BASEREQ"
}

getBaseName() {
  echo "$1" | sed 's/.pdf//' | sed 's/bitcoin\///'
}

echo "Using model: $(jq '.model' ./params/baserequest.json)"

for i in "$@"; do
  PAPERNAME=$(getBaseName "$i")
  RAWTEXT=$(pdftotext "$i" -)

  REQUEST=$(mkRequestJSON "$RAWTEXT" ./params/baserequest.json ./params/nouns.schema.json ./params/systemprompt)
  echo "Sending $PAPERNAME..."
  RAWRESPONSE=$(sendToLLM "$REQUEST")

  DATA=$(echo "$RAWRESPONSE" | jq '.choices[0].message.content | fromjson')
  echo "$DATA" >./JSON/"$PAPERNAME".json
  echo "$PAPERNAME Done!"
  echo "Sleeping for 5 seconds to prevent rate limiting issues."
  sleep 5
done
