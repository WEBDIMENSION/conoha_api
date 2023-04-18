# Conoha API

## 現在稼働中のVMリスト

```bash
docker-compose run --rm conoha_api ./conoha.sh servers
```

## VMリスト、 メモリ リスト取得

```bash
docker-compose run --rm conoha_api ./conoha.sh get_info
```

## Check variable in.env

```bash
docker-compose run --rm conoha_api ./conoha.sh check
```

## セキュリティーグループ リスト取得

```bash
docker-compose run --rm conoha_api ./conoha.sh sg
```

## VM追加

```bash
docker-compose run --rm conoha_api ./conoha.sh add_vm
```

## VM削除

```bash
docker-compose run --rm conoha_api ./conoha.sh destroy_vm <TAG_NAME>
```
