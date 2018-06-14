# Kifulog

## Synopsis

これは将棋倶楽部24の棋譜を記録して公開するサービスです。

## Install & Launch

### environment

* Softwares
  * Ruby 2.4.1
  * gem 2.6.14
  * bundler 1.16.2
  * protoc 3.2.0
  * Elasticsearch 6.2.4
* Elasticsearchを立てる。(localhost:9200)
  * `docker　run -p 9200:9200 ...` とかでよい。バックアップも何も要らない

```
git clone git@github.com:nada-wagahai/kifulog.git
cd kifulog
bundle install --path vendor/bundle
bundle exec ./server.rb
```

これだけでなんかやってくれる気がする。

### Parameters

```
--port: ポート番号
--server-name: リバースプロキシを使ってる時のパス名。 `http://server/kifu` 以下をこのサービスに転送していたら `/kifu` を指定する
```

ほかはHelpを見て。

### Help

```
./server.rb --help
```

## Synonym

プレイヤー名をつける機能。対戦相手の名前をそのまま晒すのはどうかと思ったのと、自分のアカウント名を晒したくなかったのでつけた機能。

カレントディレクトリに `synonym` という名前で `account,synonym` という形式のCSVファイルを作る。ここに書かれてないアカウント名は表示時にすべて"*****"になる。

例)
```
nada_wagahai,灘
oga_ttsu,おがた
```

## Admin

### Credentials

アップロードなどadmin機能にアクセスするにはカレントディレクトリに `credentials` ファイルを置く。

内容はCSVでBasic認証のユーザとパスワードを平文で `user,password` の形式で置くだけ。

例)
```
nada,wagahai
```

### Upload

admin画面のtextareaに将棋倶楽部24の棋譜を貼ってsubmitする。エラーとかは出るかどうかわからない。

### Import

棋譜が既にある場合、 `data/records` 以下に棋譜ファイルを置いて以下を実行するとだいたいなんとかなる。 data-dirを変えた場合などは適当にoptionsを変更する。

```
./scripts/restoredb.rb # データベース再構築 & ファイル名をそれらしく正規化
./scripts/reindex.rb # データベースのデータからElasticsearchのインデックス構築
```

### Alias

やむを得ない事情で棋譜のIDが変わってしまった場合、IDの別名をつけるとリダイレクトできる。

```
xxxxx => yyyyy
http://localhost/kifu/xxxxx/ =(redirect)=> http://localhost/kifu/yyyyy/
```

以下のコマンドを実行　する。

```
./scripts/setalias.rb xxxxx yyyyy
```

DBがアレ(Ruby.Hash)なのでサーバを再起動すると反映される。

## Contacts

Twitter: @nada_wagahai
