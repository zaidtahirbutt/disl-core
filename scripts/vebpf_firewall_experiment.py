#!/usr/bin/env python3
"""Drive UDP traffic at a VebpfManyCore firewall and report what got through.

Sends packets whose destination address or port matches each configured firewall
rule, so every rule is exercised, then reports how many were sent. Pair it with
the RISC-V debug UART and a packet capture to see what the filter dropped.

    # list the available rule sets, sizes and the delay that will be used
    ./vebpf_firewall_experiment.py --list

    # the default: VeBPF engine, IP rules, 64-byte packets
    ./vebpf_firewall_experiment.py

    ./vebpf_firewall_experiment.py --ruleset ports --size 512 --packets 2000
    ./vebpf_firewall_experiment.py --engine riscv --ruleset all --size 1500
    ./vebpf_firewall_experiment.py --size 1024 --dry-run     # print, send nothing

HOST SETUP FIRST. The IP rule set targets addresses the host must own and have
ARP entries for:  sudo ./vebpf_src_ip_arp_setup.sh   (and --reset afterwards).
Optionally  sudo ./setup_iptables_for_vebpf_exp.sh   to stop the host OS
answering on the test ports.

ONLY run this against hardware you own or are authorised to test. It generates
sustained traffic by design.
"""

import argparse
import socket
import sys
import time

# --- what the firewall is configured to match --------------------------------
# IP rules match on SOURCE address; the destination below is the host address
# that causes the board to emit a packet with that source. Port rules match the
# destination UDP port directly.
RULESETS = {
    "ip": {
        "kind": "ip",
        "targets": ["245.255.255.1", "128.0.0.1", "240.0.0.1", "1.0.0.1"],
        "help": "4 rules matching source IP (245.255.255.255, 128.0.0.0, 240.0.0.0, 1.0.0.0)",
    },
    "ports": {
        "kind": "port",
        "targets": [111, 2000, 37, 135, 137, 138, 161, 162, 514],
        "help": "9 rules matching destination UDP port (portmap, RPC, NetBIOS, SNMP, syslog...)",
    },
    "fileshare": {
        "kind": "port",
        "targets": [69, 2049, 389, 4045],
        "help": "4 rules matching destination UDP port (TFTP, NFS, LDAP, lockd)",
    },
}
RULESETS["all"] = {
    "kind": "mixed",
    "targets": None,   # every rule set in turn
    "help": "all %d rules: ip + ports + fileshare" % sum(
        len(r["targets"]) for r in RULESETS.values()),
}

DEFAULT_DEST_PORT = 1234     # used for the IP rule set
DEFAULT_HOST_IP = "129.0.0.1"

# --- packet sizes ------------------------------------------------------------
# Payload length that yields the requested frame size. 42 bytes of headers
# (14 Ethernet + 20 IPv4 + 8 UDP), and the minimum Ethernet frame is 60 bytes
# before the 4-byte CRC the NIC appends, hence the +18 on every entry.
PAYLOAD_FOR_SIZE = {
    64:   4 + 18,
    128:  68 + 18,
    256:  196 + 18,
    512:  452 + 18,
    1024: 964 + 18,
    1500: 1440 + 18,
}

# --- inter-packet delay ------------------------------------------------------
# These are MEASURED values, not theory: below them the board drops packets,
# because a larger frame takes longer to filter and the receive path has finite
# buffering. The RISC-V engine filters in software and needs roughly an order of
# magnitude more time than the VeBPF many-core does.
#
# Keyed by (engine, frame size); a few RISC-V cases also depend on the rule set,
# because more rules means more per-packet work. Anything not listed falls back
# to DEFAULT_DELAY for that engine. Override with --delay.
DEFAULT_DELAY = {"vebpf": 0.0000002, "riscv": 0.0000250}      # 200 ns / 25 us
DELAYS = {
    ("vebpf", 1024): 0.000020,      # 20 us
    ("vebpf", 1500): 0.000055,      # 55 us
    ("riscv", 1500): 0.0012000,     # 1200 us
    ("riscv", 1024): 0.0005900,     # 590 us
    ("riscv", 512):  0.0002700,     # 270 us
    ("riscv", 256):  0.0001200,     # 120 us  (ip); other rule sets below
    ("riscv", 128):  0.0000450,     # 45 us   (ip); other rule sets below
}
# Rule sets with more rules per packet need a little more room.
DELAYS_MULTI_RULE = {
    ("riscv", 256): 0.0001300,      # 130 us
    ("riscv", 128): 0.0000550,      # 55 us
}


def delay_for(engine, size, ruleset):
    """The measured inter-packet delay for this combination."""
    if ruleset != "ip" and (engine, size) in DELAYS_MULTI_RULE:
        return DELAYS_MULTI_RULE[(engine, size)]
    if (engine, size) in DELAYS:
        return DELAYS[(engine, size)]
    return DEFAULT_DELAY[engine]


def expand(ruleset):
    """-> list of (kind, target) covering every rule in the set."""
    if ruleset == "all":
        out = []
        for name in ("ip", "ports", "fileshare"):
            out += [(RULESETS[name]["kind"], t) for t in RULESETS[name]["targets"]]
        return out
    spec = RULESETS[ruleset]
    return [(spec["kind"], t) for t in spec["targets"]]


def list_config():
    print("Rule sets:")
    for name, spec in RULESETS.items():
        n = len(expand(name))
        print(f"  {name:<11} {n:>2} rules   {spec['help']}")
    print("\nFrame sizes:", ", ".join(str(s) for s in sorted(PAYLOAD_FOR_SIZE)))
    print("\nInter-packet delay (measured; below these the board drops packets):")
    print(f"  {'size':>6}  {'vebpf':>12}  {'riscv (ip)':>12}  {'riscv (multi)':>14}")
    for s in sorted(PAYLOAD_FOR_SIZE):
        print(f"  {s:>6}  {delay_for('vebpf',s,'ip')*1e6:>10.1f}us  "
              f"{delay_for('riscv',s,'ip')*1e6:>10.1f}us  "
              f"{delay_for('riscv',s,'ports')*1e6:>12.1f}us")


def main():
    p = argparse.ArgumentParser(
        description=__doc__.strip().splitlines()[0],
        epilog="See the repo README's 'Running on hardware' section.",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--engine", choices=["vebpf", "riscv"], default="vebpf",
                   help="which filter is running on the board; selects the delay table")
    p.add_argument("--ruleset", choices=sorted(RULESETS), default="ip",
                   help="which firewall rules to exercise (default: ip)")
    p.add_argument("--size", type=int, choices=sorted(PAYLOAD_FOR_SIZE), default=64,
                   help="Ethernet frame size in bytes (default: 64)")
    p.add_argument("--packets", type=int, default=2000,
                   help="packets to send per rule (default: 2000)")
    p.add_argument("--iterations", type=int, default=1,
                   help="times to repeat the whole sweep (default: 1)")
    p.add_argument("--delay", type=float, default=None,
                   help="override the inter-packet delay, in seconds")
    p.add_argument("--host", default=DEFAULT_HOST_IP,
                   help=f"destination for port-matched rules (default: {DEFAULT_HOST_IP})")
    p.add_argument("--dry-run", action="store_true",
                   help="print the plan and send nothing")
    p.add_argument("--list", action="store_true",
                   help="show rule sets, sizes and delays, then exit")
    args = p.parse_args()

    if args.list:
        list_config()
        return 0

    rules = expand(args.ruleset)
    payload = b"A" * PAYLOAD_FOR_SIZE[args.size]
    delay = args.delay if args.delay is not None else delay_for(
        args.engine, args.size, args.ruleset)
    total = len(rules) * args.packets * args.iterations

    print(f"engine      : {args.engine}")
    print(f"rule set    : {args.ruleset} ({len(rules)} rules)")
    print(f"frame size  : {args.size} B  (payload {len(payload)} B)")
    print(f"per rule    : {args.packets} packets x {args.iterations} iteration(s)")
    print(f"delay       : {delay*1e6:.3f} us between packets"
          f"{' (overridden)' if args.delay is not None else ' (measured default)'}")
    print(f"total       : {total} packets, ~{total*delay:.1f}s of sending")

    if args.dry_run:
        print("\nDRY RUN -- no socket opened, nothing sent. Targets:")
        for kind, t in rules:
            dest = (t, DEFAULT_DEST_PORT) if kind == "ip" else (args.host, t)
            print(f"  {kind:<5} -> {dest[0]}:{dest[1]}")
        return 0

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(0)
    sent = failed = 0
    started = time.time()
    try:
        for it in range(args.iterations):
            for kind, target in rules:
                host, port = ((target, DEFAULT_DEST_PORT) if kind == "ip"
                              else (args.host, target))
                for _ in range(args.packets):
                    try:
                        sock.sendto(payload, (host, port))
                        sent += 1
                    except BlockingIOError:
                        failed += 1       # socket buffer full; the send is lost
                    except OSError as exc:
                        print(f"error: sendto {host}:{port} failed: {exc}",
                              file=sys.stderr)
                        print("       is the host IP/ARP setup done? "
                              "see vebpf_src_ip_arp_setup.sh", file=sys.stderr)
                        return 1
                    time.sleep(delay)
                print(f"  {kind:<5} {host}:{port:<6} -> {args.packets} packets")
    except KeyboardInterrupt:
        print("\ninterrupted")
    finally:
        sock.close()

    elapsed = time.time() - started
    print(f"\nsent {sent} packets in {elapsed:.1f}s"
          f"  ({sent/elapsed:.0f} pkt/s)" if elapsed else "")
    if failed:
        print(f"WARNING: {failed} sends hit a full socket buffer and were lost. "
              f"Raise --delay if the board is also dropping.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
