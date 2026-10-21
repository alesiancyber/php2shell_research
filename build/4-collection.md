---
title: 4. Collection
parent: Build steps
nav_order: 4
---

# 4. Collection

Each test run's logs end up in Kusto tables with the real Sentinel schemas, so queries carry over to Microsoft Sentinel unchanged. Fluent Bit collects inside the VM; the Mac pulls each run, archives it in Azurite and loads it.

## Mac side: Azurite and Kusto

[`docker-compose.yml`](https://github.com/{{ site.github.repository_nwo }}/blob/main/docker-compose.yml) runs both. Everything they store goes under `lab-data/` (git-ignored).

<details markdown="block">
<summary>One-time setup</summary>

```bash
mkdir -p lab-data/certs && cd lab-data/certs
# Azurite needs HTTPS: the Kusto engine refuses plain-HTTP storage URLs
openssl req -x509 -newkey rsa:2048 -nodes -days 825 -keyout key.pem -out cert.pem -subj "/CN=azurite" \
  -addext "subjectAltName=DNS:host.docker.internal,DNS:localhost,IP:127.0.0.1"
# Kusto must trust that cert: its own CA list plus cert.pem
docker run --rm --platform linux/amd64 --entrypoint cat mcr.microsoft.com/azuredataexplorer/kustainer-linux:latest \
  /etc/ssl/certs/ca-certificates.crt > ca-bundle.pem && cat cert.pem >> ca-bundle.pem
cd ../.. && docker compose up -d

# Blob container and a read-only SAS for Kusto
export AZURITE_CONN="DefaultEndpointsProtocol=https;AccountName=devstoreaccount1;AccountKey=<Azurite's documented dev key>;BlobEndpoint=https://127.0.0.1:10000/devstoreaccount1;"
export REQUESTS_CA_BUNDLE=lab-data/certs/cert.pem
az storage container create -n winlab --connection-string "$AZURITE_CONN"
echo "WINLAB_READ_SAS='$(az storage container generate-sas -n winlab --permissions rl --expiry 2027-01-01T00:00Z --https-only --connection-string "$AZURITE_CONN" -o tsv)'" > lab-data/.env

# Saved Kusto database with the lab's tables (re-attach after every container start)
scripts/kx.py -d NetDefaultDB '.create database WinLab persist (@"/kustodata/dbs/WinLab/md", @"/kustodata/dbs/WinLab/data")'
scripts/kx.py -f kql/tables.kql
```

After a Kusto container restart: `scripts/kx.py -d NetDefaultDB '.attach database WinLab from @"/kustodata/dbs/WinLab/md"'`.
</details>

## VM side: Fluent Bit

[`phase4-fluentbit.ps1`]({{ '/scripts/phase4-fluentbit.ps1' | relative_url }}) installs Fluent Bit (ARM64, hash-checked) as a LocalSystem service. It writes one JSON-lines file per source to `C:\Lab\ship`: `winevt.jsonl` (seven Event Log channels, Security and Sysmon included), `iis.jsonl`, `php.jsonl` and `httperr.jsonl`. Then snapshot: `prlctl snapshot WinLab -n logging-baseline`.

## Collecting a run

```bash
scripts/collect-run.sh LAB-RUN-<id>
```

1. [`collect-vm.ps1`]({{ '/scripts/collect-vm.ps1' | relative_url }}) sends a marker request and waits until Fluent Bit has shipped it, because IIS writes its log lazily. It then moves the JSON-lines files and any new FREB traces into one zip.
2. The Mac pulls the zip into `lab-data/runs/<id>/` and uploads it to Azurite under `winlab/runs/<id>/`.
3. [`load-run.py`]({{ '/scripts/load-run.py' | relative_url }}) stages each file in Kusto and runs [`kql/transform.kql`]({{ '/kql/transform.kql' | relative_url }}). Every row gets `_ResourceId = "winlab/<id>"`. Re-running replaces the run's rows.

## Where each source lands

| Source | Kusto table | Notes |
| --- | --- | --- |
| Security channel | `SecurityEvent` | Common columns plus named fields for 4688, 4689 and 4663 |
| Other channels (Sysmon, PowerShell, IIS config, Defender, Application, System) | `Event` | `EventData` is a JSON array; Azure Monitor Agent writes XML |
| IIS W3C log | `W3CIISLog` | The custom `ContentType` and `XFF` fields have no column; they stay in `iis.jsonl` |
| PHP error log | `PhpErrorLog_CL` | Level, message, file and line parsed out |
| HTTPERR | `HttpErrLog_CL` | One column per field |
