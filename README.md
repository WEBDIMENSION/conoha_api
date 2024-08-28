# Conoha API

*Keypairは登録済みであること！

## 現在稼働中のVMリスト

```bash
# create json/servers.json
docker-compose run --rm conoha_api ./conoha.sh servers
```

## VMリスト、 メモリ リスト取得

```bash
# create json/images.json
# create json/flavors.json
docker-compose run --rm conoha_api ./conoha.sh get_info
```

## Check variable in.env

```bash
docker-compose run --rm conoha_api ./conoha.sh check
```

## セキュリティーグループ リスト取得

```bash
# create json/sg.json
docker-compose run --rm conoha_api ./conoha.sh sg
```

## VM追加

```bash
# create json/vm.json
docker-compose run --rm conoha_api ./conoha.sh add_vm
```

## VM削除

```bash
docker-compose run --rm conoha_api ./conoha.sh destroy_vm <TAG_NAME>
```
## VM 再インストール

```bash
docker-compose run --rm conoha_api ./conoha.sh reset <TAG_NAME>
```
