#!/usr/bin/env bash
# Create the spx-linux apt signing key and store the CI parts as GitHub environment secrets.
# Run it yourself, in a terminal (Git Bash or Linux), never through an assistant. You type the
# passphrase; it isn't stored anywhere except as the APT_SIGNING_PASSPHRASE secret.
#
#  - primary key: ed25519, certify-only, 5 years. It stays OFFLINE with you (backup file below).
#  - signing subkey: ed25519, 2 years. Only this subkey goes to GitHub (environment "apt-publish").
#  - public key: spx-archive-keyring.gpg/.asc, published on the apt repo page.
#
# Usage: packaging/make-apt-signing-key.sh [OUT_DIR]     (default: ~/spx-apt-key)
set -euo pipefail
REPO=${REPO:-tawheedmm/spx-linux}
ENV=${ENV:-apt-publish}
OUT=${1:-$HOME/spx-apt-key}
NAME="spx-linux apt repository signing key"

command -v gpg >/dev/null || { echo "gpg not found"; exit 1; }
command -v gh  >/dev/null || { echo "gh (GitHub CLI) not found"; exit 1; }
gh api "repos/$REPO/environments/$ENV" </dev/null >/dev/null 2>&1 || { echo "environment '$ENV' does not exist on $REPO yet"; exit 1; }
[ ! -e "$OUT" ] || { echo "$OUT already exists; move it away first (refusing to overwrite a key)"; exit 1; }

mkdir -p "$OUT/gnupg"; chmod 700 "$OUT" "$OUT/gnupg"
export GNUPGHOME="$OUT/gnupg"

echo "Creating: $NAME"
read -rsp "New passphrase (12+ characters; you'll need it to renew or revoke the key): " P; echo
read -rsp "Repeat passphrase: " P2; echo
[ "$P" = "$P2" ] || { echo "passphrases differ"; exit 1; }
[ ${#P} -ge 12 ] || { echo "too short"; exit 1; }
unset P2
g() { gpg --batch --pinentry-mode loopback --passphrase-fd 3 "$@" 3<<<"$P"; }

g --quick-generate-key "$NAME" ed25519 cert 5y
FPR=$(gpg --list-keys --with-colons "$NAME" | awk -F: '/^fpr/{print $10; exit}')
g --quick-add-key "$FPR" ed25519 sign 2y
SUB=$(gpg --list-keys --with-colons "$FPR" | awk -F: '/^sub/{s=1; next} s && /^fpr/{print $10; s=0}' | tail -1)

gpg --armor --export "$FPR" > "$OUT/spx-archive-keyring.asc"
gpg --export "$FPR"         > "$OUT/spx-archive-keyring.gpg"
g --armor --export-secret-keys "$FPR"     > "$OUT/PRIMARY-SECRET-KEY-backup.asc"
g --armor --export-secret-subkeys "$SUB!" > "$OUT/signing-subkey.asc"
cp "$GNUPGHOME"/openpgp-revocs.d/"$FPR".rev "$OUT/REVOCATION-CERT.rev" 2>/dev/null || true

echo "Uploading the signing subkey, fingerprint and passphrase to $REPO (environment $ENV)..."
gh secret set APT_SIGNING_KEY        --repo "$REPO" --env "$ENV" < "$OUT/signing-subkey.asc"
printf %s "$FPR" | gh secret set APT_SIGNING_KEY_ID     --repo "$REPO" --env "$ENV"
printf %s "$P"   | gh secret set APT_SIGNING_PASSPHRASE --repo "$REPO" --env "$ENV"
unset P
rm -f "$OUT/signing-subkey.asc"

echo
echo "Done. Fingerprint (publish this): $FPR"
echo "Public key:   $OUT/spx-archive-keyring.gpg (and .asc)"
echo "KEEP OFFLINE: $OUT/PRIMARY-SECRET-KEY-backup.asc, $OUT/REVOCATION-CERT.rev and $OUT/gnupg"
echo "Copy those to a USB stick or password manager, then delete them from this disk."
