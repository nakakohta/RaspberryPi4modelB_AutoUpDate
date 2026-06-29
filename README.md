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

```bash
sudo install -m 0755 apt-auto-maintenance.sh /usr/local/sbin/apt-auto-maintenance.sh
sudo install -m 0644 apt-auto-maintenance.logrotate /etc/logrotate.d/apt-auto-maintenance
```

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

logrotate設定のドライラン確認例です。

```bash
sudo logrotate -d /etc/logrotate.d/apt-auto-maintenance
```

## 動作確認

構文チェック:

```bash
bash -n apt-auto-maintenance.sh
```

`shellcheck` が利用できる環境では、静的チェックも推奨します。

```bash
shellcheck apt-auto-maintenance.sh
```
