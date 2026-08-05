#  個人用terraformコマンド備忘録

#　yesなしapply
terraform apply -auto-approve

#　yesなしdestroy
terraform destroy -auto-approve

#　サブディレクトリまでフォーマットを整えたいとき
terraform fmt -recursive

# 構文チェック
terraform validate

# 現在の状態ファイルの内容を表示
terraform show

# output 変数の値を表示。
terraform output

# 変数やモジュールの値を簡単に確認できる
terraform console

# 管理対象リソースの一覧表示
terraform state list

# 特定リソースの状態詳細を表示
terraform state show <リソース名>

# 状態ファイル内でリソースを移動
terraform state mv <旧リソース名> <新リソース名>

# 状態ファイルからリソースを削除
terraform state rm <リソース名>

# 依存関係をグラフ化]
terraform graph > portfolio.dot