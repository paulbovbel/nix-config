# The NixOS test driver supplies these globals.
# ruff: noqa: F821
start_all()
machine.wait_for_unit("exposed.service")
machine.wait_for_unit("internal.service")

# Emulate ingress interfaces without requiring a live Tailscale account.
for namespace, interface, subnet in [
    ("tail", "tailnet-test", "198.51.100"),
    ("lan", "lan-test", "192.0.2"),
]:
    machine.succeed(
        f"ip netns add {namespace}; "
        f"ip link add {interface} type veth peer name peer-{namespace}; "
        f"ip link set peer-{namespace} netns {namespace}; "
        f"ip address add {subnet}.1/24 dev {interface}; "
        f"ip link set {interface} up; "
        f"ip netns exec {namespace} ip address add {subnet}.2/24 dev peer-{namespace}; "
        f"ip netns exec {namespace} ip link set peer-{namespace} up; "
        f"ip netns exec {namespace} ip link set lo up"
    )

machine.wait_until_succeeds(
    "ip netns exec tail curl --fail --max-time 3 http://198.51.100.1:8080"
)
machine.fail("ip netns exec lan curl --fail --max-time 3 http://192.0.2.1:8080")
machine.succeed(
    "podman exec exposed python3 -c "
    "\"import urllib.request; urllib.request.urlopen('http://internal:8000')\""
)
assert machine.succeed("podman port internal").strip() == ""
machine.fail("ip netns exec tail curl --fail --max-time 3 http://198.51.100.1:8000")
machine.fail("ip netns exec lan curl --fail --max-time 3 http://192.0.2.1:8000")
