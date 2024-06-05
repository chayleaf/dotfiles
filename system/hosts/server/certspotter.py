import argparse
import hashlib
import requests
import subprocess
import traceback
from datetime import date
from pyasn1.codec.der.decoder import decode
from pyasn1.codec.der.encoder import encode
from pyasn1_modules import rfc5280
from cryptography import x509


def calc_tbs(pem: bytes) -> str:
    cert = x509.load_pem_x509_certificate(pem)
    tbs, _leftover = decode(
        cert.tbs_certificate_bytes, asn1Spec=rfc5280.TBSCertificate()
    )
    precert_exts = [
        v.dotted_string
        for k, v in x509.ExtensionOID.__dict__.items()
        if k.startswith("PRECERT_")
    ]
    exts = [ext for ext in tbs["extensions"] if str(ext["extnID"]) not in precert_exts]
    tbs["extensions"].clear()
    tbs["extensions"].extend(exts)
    return hashlib.sha256(encode(tbs)).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(required=True)
    spot = subparsers.add_parser("spot")
    spot.set_defaults(func=spotter)
    spot.add_argument("--sendmail", "-s", type=str, required=True)
    spot.add_argument("--from", "-f", type=str, required=False, default="Certificate Monitoring")
    spot.add_argument("--to", "-t", type=str, required=False)
    spot.add_argument("--domain", "-d", type=str, required=True)
    spot.add_argument("--cache_file", "-c", type=str, required=True)
    spot.add_argument("certs", type=str, nargs="*")
    tbs = subparsers.add_parser("tbs")
    tbs.set_defaults(func=print_tbs)
    tbs.add_argument("path", type=str)
    args = parser.parse_args()
    args.func(args)


def print_tbs(args) -> None:
    with open(args.path, "rb") as f:
        print(calc_tbs(f.read()))


def send_mail(
    sendmail: str, from_: str | None, to: str | None, subject: str, text: str
):
    proc = subprocess.Popen(
        [sendmail, "-i"] + (["-F", from_] if from_ else []) + (['--', to] if to else []),
        stdin=subprocess.PIPE,
    )
    assert proc.stdin is not None
    proc.stdin.write(f"Subject: {subject}\n\n".encode("utf-8"))
    proc.stdin.write((text + "\n").encode("utf-8"))
    proc.stdin.close()
    proc.wait()
    assert proc.returncode == 0


def spotter(args) -> None:
    try:
        spotter1(args)
    except Exception:
        subject = "Certificate monitoring failure"
        text = traceback.format_exc()
        send_mail(args.sendmail, args.__dict__["from"], args.to, subject, text)


def spotter1(args) -> None:
    url = f"https://crt.sh/?CN={args.domain}&dir=^&sort=1&group=none"

    try:
        with open(args.cache_file, "rt") as f:
            lastid = int(f.read())
    except FileNotFoundError:
        lastid = 0

    body = requests.get(url).text

    def parse_row(row: str, tag: str) -> list[str]:
        ret = []
        for col in row.split(f"</{tag}>")[:-1]:
            if "</A>" in col:
                col = col.split("</A>")[-2].split(">")[-1]
            else:
                col = col.split(">")[-1]
            ret.append(col)
        return ret

    cols: list[str] = []
    rows: list[dict[str, str]] = []
    for s_row in body.split("<TR>")[2:]:
        s_row = s_row.split("</TR>")[0]
        if "<TH" in s_row:
            cols = parse_row(s_row, "TH")
        elif cols:
            rows.append({k: v for k, v in zip(cols, parse_row(s_row, "TD"))})

    today = date.today()
    pem_urls = {}
    issuers = {}
    cns = {}

    if not rows:
        raise Exception("No rows found!")

    for row in rows:
        crtid = int(row["crt.sh ID"])
        if crtid <= lastid:
            continue
        d = date.fromisoformat(row["Logged At"])
        if (today - d).days > 30:
            continue
        pem_urls[crtid] = f"https://crt.sh/?d={crtid}"
        issuers[crtid] = row.get("Issuer Name", "")
        cns[crtid] = row.get("Matching Identities", "")

    if not pem_urls:
        return

    valid_hashes: set[str] = set()
    for path in args.certs:
        with open(path, "rb") as f1:
            valid_hashes.add(calc_tbs(f1.read()))

    pems: dict[int, bytes] = {}

    for id, pem_url in pem_urls.items():
        lastid = max(id, lastid)
        pems[id] = requests.get(pem_url).content

    invalid_ids: set[int] = set()

    for id, pem in pems.items():
        if calc_tbs(pem) not in valid_hashes:
            invalid_ids.add(id)

    if invalid_ids:
        subject = f"{len(invalid_ids)} invalid certs discovered!"
        text = "\n".join(
            f"https://crt.sh/?id={id} ({cns[id]}, {issuers[id]})"
            for id in sorted(invalid_ids)
        )
        send_mail(args.sendmail, args.__dict__["from"], args.to, subject, text)

    with open(args.cache_file, "wt") as f:
        f.write(str(lastid))


if __name__ == "__main__":
    main()
