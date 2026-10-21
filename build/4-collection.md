---
title: 4. Collection
parent: Build steps
nav_order: 4
---

# 4. Collection

Each test run's logs end up in Kusto tables with the real Sentinel schemas, so queries carry over to Microsoft Sentinel unchanged. Fluent Bit collects inside the VM; the host pulls each run, archives it in Azurite and loads it.

## Host side: Azurite and Kusto

Run both as containers, however you prefer. The scripts expect:

| Service | Image | Port on the host | Needs |
| --- | --- | --- | --- |
| Azurite (blob only) | `mcr.microsoft.com/azure-storage/azurite` | 10000 | HTTPS with `cert.pem` / `key.pem` (`--cert`, `--key`); data volume |
| Kusto emulator | `mcr.microsoft.com/azuredataexplorer/kustainer-linux` (amd64 only; on an ARM host it runs under emulation, Rosetta on a Mac) | 8085 → container 8080 | `ACCEPT_EULA=Y`; `SSL_CERT_FILE` pointing at `ca-bundle.pem` so it trusts Azurite; a `/kustodata` volume for saved databases; about 4 GB of memory |

Kusto reaches Azurite at `https://host.docker.internal:10000` (the default in `load-run.py`), which is why the certificate names that host. Docker Desktop provides that name; on Linux Docker, add `--add-host=host.docker.internal:host-gateway` to the Kusto container. Keep everything they store under `lab-data/` (git-ignored).

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
cd ../..
# start Azurite and Kusto now (see the table above)

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

[`phase4-fluentbit.ps1`]({{ '/scripts/phase4-fluentbit.ps1' | relative_url }}) installs Fluent Bit (hash-checked) as a LocalSystem service. It downloads the ARM64 build (`winarm64`); on x64, change the zip name to the `win64` build and its hash. It writes one JSON-lines file per source to `C:\Lab\ship`: `winevt.jsonl` (seven Event Log channels, Security and Sysmon included), `iis.jsonl`, `php.jsonl` and `httperr.jsonl`. Then take a snapshot named `logging-baseline`.

## Collecting a run

```bash
scripts/collect-run.sh LAB-RUN-<id>
```

1. [`collect-vm.ps1`]({{ '/scripts/collect-vm.ps1' | relative_url }}) sends a marker request and waits until Fluent Bit has shipped it, because IIS writes its log lazily. It then moves the JSON-lines files and any new FREB traces into one zip.
2. The host pulls the zip into `lab-data/runs/<id>/` and uploads it to Azurite under `winlab/runs/<id>/`.
3. [`load-run.py`]({{ '/scripts/load-run.py' | relative_url }}) stages each file in Kusto and runs [`kql/transform.kql`]({{ '/kql/transform.kql' | relative_url }}). Every row gets `_ResourceId = "winlab/<id>"`. Re-running replaces the run's rows.

## Where each source lands

| Source | Kusto table | Notes |
| --- | --- | --- |
| Security channel | `SecurityEvent` | Common columns plus named fields for 4688, 4689 and 4663 |
| Other channels (Sysmon, PowerShell, IIS config, Defender, Application, System) | `Event` | `EventData` is a JSON array; Azure Monitor Agent writes XML |
| IIS W3C log | `W3CIISLog` | The custom `ContentType` and `XFF` fields have no column; they stay in `iis.jsonl` |
| PHP error log | `PhpErrorLog_CL` | Level, message, file and line parsed out |
| HTTPERR | `HttpErrLog_CL` | One column per field |
