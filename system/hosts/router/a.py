import traceback





import pytricia  # type: ignore

def build_ipset(ips: list[str]) -> pytricia.PyTricia:
    pyt = pytricia.PyTricia()
    for ip in ips:
        try:
            pyt.insert(ip, None)
        except:
            with open("/var/lib/unbound/error.log", "at") as f:
                f.write(f"Warning: couldn't insert ip {ip}:\n")
                traceback.print_exc(file=f)
    return pyt

s = build_ipset(["10.0.0.0/24"])
