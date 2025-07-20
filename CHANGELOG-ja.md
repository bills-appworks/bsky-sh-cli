# v0.18.0
## 追加
- リポストに対するいいね・リポストでのリポスト者への通知に対応（like/repost）
- リポスト者への通知抑止オプション追加（--notify-origin-only）
- いいね・リポストコマンドのURI/CID指定形式でのリポストURI/CID指定オプション追加（like/repost --via-uri/--via-cid）
## 変更
- ID出力モードでのリポストURI/CID出力対応（--output-id）
## 修正
- セション情報JSON出力でフィードインデックスがリプライ関係等でハイフン混じりの場合に数値型として不正なJSONとなっていたため文字列型として出力するよう修正（info session --output-json）

# v0.17.0
## 追加
- プロファイル個別カスタマイズ設定ファイル対応（`$HOME/.bsky_sh_cli_<プロファイル名>_rc`）
- GNU sedパス指定対応（環境変数`BSKYSHCLI_GNU_SED_PATH`）
- インストーラのGNU sedパス指定対応（`install.sh --config-gsed-path`）
- 構成情報出力にGNU sedパス指定情報追加（`info meta --path (BSKYSHCLI_GNU_SED_PATH)`）
## 修正
- その他軽微な修正

# v0.16.0
## 追加
- テキストリンク投稿機能対応（`[テキスト](URL)`）
- スレッド投稿機能（posts）でのリンクカード出力対象指定オプション（--linkcard-index）対応（コマンドラインオプションおよび区切りセクションオプションディレクティブ）
- ログインシェルcsh/tcsh対応（インストーラPATH設定）
- プラットフォーム向けチューニング（FreeBSD）
- READMEに動作を確認したことがある環境を記載
## 変更
- リンクカードのOGP画像サイズが大きい場合のImageMagick convertリサイズパラメタを`800x512!`から`800x512`に変更（アスペクト比を維持するように変更）（BSKYSHCLI_LINKCARD_RESIZE_CONVERT_PARAM）
- mktempコマンドで`--tmpdir(-p)`オプションが利用できない環境でも動作するよう対応
- 管理者権限インストール時に対応済のログインシェル（bash/zsh/csh/tcsh）全種の初期設定ファイルを更新対象とするよう変更
## 修正
- スレッド投稿機能（posts）での区切りセクションオプションディレクティブがひとつ前のセクションに適用されるケースの修正
- その他軽微な修正

# v0.15.0
## 追加
- ビデオ投稿機能対応(post --video) #6
- ポスト表示時のビデオ対応（関連情報のテキスト出力のみ）
- 必要ツールに"ffprobe"コマンド（ffmpegパッケージ）を追加
  - ビデオ投稿時のアスペクト比設定に必要（ツールが無ければアスペクト比指定無しで投稿）
- APIラッパースクリプトを追加
  - app.bsky.video.getJobStatus
  - app.bsky.video.getUploadLimits
  - app.bsky.video.uploadVideo
  - com.atproto.server.describeServer
  - com.atproto.server.getServiceAuth
  - com.atproto.sync.getBlob
  - com.atproto.sync.listBlobs
## 変更
- GET系APIでのリダイレクトに対応
## 修正
- その他軽微な修正

# v0.14.0
## 追加
- プラットフォーム向けチューニング
  - macOS
  - さくらのクラウドシェル
  - Amazon Web Services CloudShell
## 修正
- 出力構成情報の修正（info meta）
- その他軽微な修正

# v0.13.0
## 追加
- セルフホストPDSに対応(BSKYSHCLI_SELFHOSTED_DOMAIN) #5
- APIラッパースクリプト追加(searchPosts/listRecords)
- 必要ツールに"/usr/bin/convert"コマンド（imagemagickパッケージ）を追加
  - リンクカードOGP画像ファイルのリサイズに必要（ツールが無ければリサイズ無し）
## 変更
- リンクカードOGP画像ファイルサイズが2MBを超える場合にリサイズを実施(imagemagick convert) #5
## 修正
- その他軽微な修正

# v0.12.1
## 修正
- ヘルプの誤りを修正

# v0.12.0
## 追加
- フォロー/フォロワー表示機能（socialコマンド）
- APIラッパースクリプトを追加
  - app.bsky.graph.getFollowers
  - app.bsky.graph.getFollows
  - app.bsky.graph.getKnowFollowers
## 修正
- その他軽微な修正

# v0.11.1
## 修正
- rootユーザ（またはsudo）でインストーラを使って新規にインストールした場合にroot以外のユーザがツールを利用できない不具合を修正（過剰なパーミッション制約の削減）
- インストールおよびアップデートに関するドキュメントの改善
- ダウンロードインストーラの必要ツールチェックを実施
- インストール時の.bsky_sh_cli_rcファイル配備パーミッション調整
- （デバックモード実行時）過剰なデバック情報出力の削減
- （開発者向け）ShellCheck version 0.9.0対応

# v0.11.0
## 追加
- 引用数の表示
- 切り離された引用の表示メッセージ対応
- スレッドミュート非表示対象対応
## 変更
- アカウントブロック対象の表示メッセージを改善
## 修正
- 軽微な修正

# v0.10.0
## 追加
- リプライ先やリポスト者のポスト補助情報表示
- ダウンロードインストーラ
## 変更
- タイムラインやスレッドの表示を改善
## 修正
- 軽微な修正

# v0.9.0
## 追加
- スレッド投稿機能でのポスト個別オプション指定（postsコマンドでの区切りセクションオプションディレクティブ機能）
- セルフアップデート機能（updateコマンド）
## 修正
- 軽微な修正

# v0.8.0
## 追加
- 投稿系機能（post/posts/reply/quoteコマンド）でのプレビュー機能対応（--previewオプション）
- ポストテキスト内のメンション対応 [#1](https://github.com/bills-appworks/bsky-sh-cli/issues/1)
- ポスト表示時の投稿時指定言語出力オプションを追加（--output-langsオプション）
- ポスト表示時のハッシュタグ抽出表示対応
## 変更
- 投稿結果表示の改善
## 修正
- 軽微な修正

# v0.7.0
## 追加
- ポストテキスト内のURL短縮対応
- ポストテキスト内のハッシュタグ対応
## 変更
- ポスト表示日時フィールドをcreatedAtからindexedAtに変更
## 修正
- デバッグモード時ログの一部に出力されていたJWTトークンを除去
- その他軽微な修正

# v0.6.0
## 追加
- 標準入力（パイプ・リダイレクト・対話式）対応（post/posts/reply/quote/sizeコマンド）
- ほとんどのコマンドにJSON出力オプションを追加（--output-jsonオプション）
- スレッド投稿機能（postsコマンド）で区切り文字列指定による1ファイル内複数投稿に対応（--separator-prefixオプション）
- 単一投稿系機能（post/reply/quoteコマンド）でテキストファイル指定に対応（--text-fileオプション）
## 修正
- 軽微な修正

# v0.5.0
## 追加
- スレッド投稿等の複数ポスト機能（postsコマンド）
- 投稿テキストの文字数確認機能（sizeコマンド）
- via対応（投稿クライアント名の非公式フィールド）
- APIラッパースクリプトに"app.bsky.feed.getPosts"を追加
## 変更
- 投稿系コマンドでの実行結果表示の改善
- 軽微な変更

# v0.4.0
## 追加
- 投稿時のlangs（言語コード）指定
- 簡易インストーラ
## 変更
- デバッグ関連ファイル出力ディレクトリの変更
- 軽微な変更

# v0.3.1
## 修正
- OGP画像の作業ディレクトリがテンポラリディレクトリではなくカレントディレクトリになっていた不具合を修正

# v0.3.0
## 追加
- ポストでのリンクURLサポート
  - 投稿テキストにリンクURLが含まれる場合リンクカードを生成
  - リンクカードの表示
  - テキストに含まれるリンクURLをポスト末尾に表示（短縮されている場合フルURLを表示）

# v0.2.0
## 追加
- 画像ポストサポート（コマンド：post/reply/quote）
  - タイムライン等のポストでの表示は従来通りURLのみ。
- 必要ツールに"file"コマンド（libmagicパッケージ）を追加
  - 画像利用時のみに必要
- APIラッパースクリプトに"com.atproto.repo.uploadBlob"を追加
- CHANGELOGファイル
## 変更
- 画像インデックス表記の"image-"文字列をインデックス値からテンプレートに移行
## 修正
- 軽微な修正

# v0.1.0
- 初回リリース