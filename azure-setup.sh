#!/bin/bash

### サービスプリンシパル作成スクリプト ###

# サブスクリプションIDを取得
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# サービスプリンシパルの作成
# SP_INFO=$(az ad sp create-for-rbac \
#   --role="Contributor" \
#   --scopes="/subscriptions/${SUBSCRIPTION_ID}" \
#   --sdk-auth)

# サービスプリンシパル情報を保存
echo "$SP_INFO" > sp_credentials.json
echo "サービスプリンシパルを作成し、sp_credentials.json に保存しました。"

# .terraformrc または provider.tf に使うために抜粋表示
echo "以下の値をTerraformのprovider設定に使ってください："
echo "client_id: $(echo "$SP_INFO" | jq -r '.clientId')"
echo "client_secret: $(echo "$SP_INFO" | jq -r '.clientSecret')"
echo "tenant_id: $(echo "$SP_INFO" | jq -r '.tenantId')"
echo "subscription_id: $SUBSCRIPTION_ID"