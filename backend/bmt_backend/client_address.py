"""Resolve rate-limit identity only across an explicitly trusted proxy chain."""
import ipaddress


def proxy_networks(values):
    networks = tuple(ipaddress.ip_network(value, strict=False) for value in values)
    for version in (4, 6):
        if any(net.prefixlen == 0 for net in ipaddress.collapse_addresses(
                net for net in networks if net.version == version)):
            raise ValueError("Trusted proxies must not include the whole internet")
    return networks


def address(value):
    try:
        parsed = ipaddress.ip_address(value)
        return parsed.ipv4_mapped if isinstance(parsed, ipaddress.IPv6Address) and parsed.ipv4_mapped else parsed
    except ValueError:
        return None


class ClientAddress:
    def __init__(self, networks=()):
        self.networks = proxy_networks(networks)

    def trusted(self, peer):
        return peer is not None and any(peer in network for network in self.networks)

    def resolve(self, scope):
        raw_peer = (scope.get("client") or ("unknown", 0))[0]
        peer = address(raw_peer)
        fallback = str(peer) if peer is not None else str(raw_peer)
        if not self.trusted(peer):
            return fallback
        values = [value for key, value in scope.get("headers", ()) if key.lower() == b"x-forwarded-for"]
        if not values or sum(map(len, values)) > 4096:
            return fallback
        try:
            hops = b",".join(values).decode("ascii").split(",")
        except UnicodeError:
            return fallback
        if len(hops) > 32:
            return fallback
        current = peer
        for hop in reversed(hops):
            if not self.trusted(current):
                break  # Earlier caller-supplied addresses are outside the trust chain.
            current = address(hop.strip())
            if current is None:
                return fallback
        return str(current)
