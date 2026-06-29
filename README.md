# Raspberry Pi APT Auto Maintenance

Raspberry Pi OS / Debian系でAPTの定期メンテナンスを行うためのBashスクリプトです。
root権限でcronから実行される前提です。

このスクリプトは `rpi-update` を使いません。
また、`apt autoremove --purge` も使いません。

## 実行内容

`apt-auto-maintenance.sh` は次の順番で処理します。

1. `apt-get update`
2. `apt-get full-upgrade -y`
3. `apt-get autoremove -y`
4. `/var/run/reboot-required` が存在する場合のみ `reboot`

`full-upgrade` は `DEBIAN_FRONTEND=noninteractive` に加えて、dpkgの設定ファイル確認で止まりにくくするために `--force-confdef` と `--force-confold` を指定します。
これにより、既定の処理がある場合はそれに従い、判断が必要な場合は既存の設定ファイルを維持します。

実行ログは `/var/log/apt-auto-maintenance.log` に追記されます。
root以外で実行された場合は、ログファイルには書き込まずstderrへ理由を出して終了します。

## インストール

Raspberry Pi上でリポジトリを取得してから、スクリプト、logrotate設定、cron設定を配置します。
以下の手順は、Raspberry Pi OS / Debian系で `sudo` が使えるユーザーとして実行してください。

### 1. リポジトリを取得

```bash
mkdir -p ~/workspace
cd ~/workspace
git clone https://github.com/nakakohta/RaspberryPi4modelB_AutoUpDate.git
cd RaspberryPi4modelB_AutoUpDate
```

すでにclone済みの場合は、最新化します。

```bash
cd ~/workspace/RaspberryPi4modelB_AutoUpDate
git pull --ff-only origin main
```

### 2. スクリプトを配置

```bash
sudo install -m 0755 apt-auto-maintenance.sh /usr/local/sbin/apt-auto-maintenance.sh
```

### 3. ログローテーションを設定

ログの肥大化を防ぐため、logrotate設定を配置します。

```bash
sudo install -m 0644 apt-auto-maintenance.logrotate /etc/logrotate.d/apt-auto-maintenance
```

### 4. cron設定を配置

`/etc/cron.d/apt-auto-maintenance` を作成します。
次の例では、毎月第2日曜日の05:30にrootで実行します。

```bash
sudo tee /etc/cron.d/apt-auto-maintenance >/dev/null <<'EOF'
30 5 8-14 * * root [ "$(date +\%u)" = "7" ] && /usr/local/sbin/apt-auto-maintenance.sh
EOF
sudo chmod 0644 /etc/cron.d/apt-auto-maintenance
sudo chown root:root /etc/cron.d/apt-auto-maintenance
```

cronサービスが無効な環境では、有効化して起動します。

```bash
sudo systemctl enable --now cron
```

### 5. すぐに一度実行する場合

cronを待たずに一度だけ手動実行する場合は、次を実行します。

```bash
sudo /usr/local/sbin/apt-auto-maintenance.sh
```

このコマンドは実際に `apt-get update`、`apt-get full-upgrade -y`、`apt-get autoremove -y` を実行します。
`/var/run/reboot-required` が存在する場合は自動で再起動します。

## cron設定例

`/etc/cron.d/apt-auto-maintenance` を作成し、毎月第2日曜日の05:30にrootで実行する例です。

```cron
30 5 8-14 * * root [ "$(date +\%u)" = "7" ] && /usr/local/sbin/apt-auto-maintenance.sh
```

このcron設定の意味は次のとおりです。

- `30 5` は05:30を表します。
- `8-14` は毎月8日から14日を表します。
- `date +%u` は曜日番号を返し、`7` は日曜日を表します。
- これらを組み合わせて、毎月第2日曜日の05:30だけ実行します。

実行時刻を変更したい場合は、先頭の分と時を変更します。
たとえば04:15に実行したい場合は、先頭を `15 4` に変更します。

## ログ確認

```bash
sudo tail -n 100 /var/log/apt-auto-maintenance.log
```

## ログローテーション

ログ肥大化を防ぐため、`apt-auto-maintenance.logrotate` を `/etc/logrotate.d/apt-auto-maintenance` に配置します。

設定内容は次の方針です。

- 週次ローテーション
- 8世代保持
- 圧縮
- 空ログはローテーションしない
- ログファイルが存在しなくてもエラーにしない
