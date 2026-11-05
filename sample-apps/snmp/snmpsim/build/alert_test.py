#!/usr/bin/env python3
"""Drive the SNMP sample app's alerts on demand.

Run it from the sample app directory:

    make alert-test CMD="<command> [minutes]"

Commands:
  interface-down warning|critical   take net.cisco.c2911's uplink or critical interface down
  interface-up warning|critical     bring it back up
  reboot                            set net.cisco.c2911's uptime to 60 seconds
  fru-fail, fru-on                  fail or restore a power supply on net.cisco.c7600
  cpu-high, cpu-normal              set net.cisco.c2911's CPU to 95% or back to 3%
  memory-high, memory-normal        set net.cisco.c2911's processor memory to 95% used or back
  errors [minutes]                  add errors on net.cisco.c2911's uplink every 10 seconds, 20 minutes by default
  drops [minutes]                   add discards on net.cisco.c2911's uplink every 10 seconds, 35 minutes by default
  fc-errors [minutes]               add invalid transmission words, invalid CRCs and discarded frames on
                                    net.cisco.mds9148s's fc1/1 every 10 seconds, 20 minutes by default
"""
import asyncio
import sys
import time

from pysnmp.hlapi.v3arch.asyncio import (
    CommunityData,
    ContextData,
    ObjectIdentity,
    ObjectType,
    SnmpEngine,
    UdpTransportTarget,
    get_cmd,
    set_cmd,
)
from pysnmp.proto.rfc1902 import Counter32, Gauge32, Integer32, TimeTicks

LAB = "net.cisco.c2911"
FRU = "net.cisco.c7600"
FC = "net.cisco.mds9148s"
INTERFACES = {"warning": "2", "critical": "8"}
UPLINK = INTERFACES["warning"]

IF_OPER_STATUS = "1.3.6.1.2.1.2.2.1.8."
SYS_UPTIME = "1.3.6.1.2.1.1.3.0"
FRU_POWER_STATUS = "1.3.6.1.4.1.9.9.117.1.1.2.1.2.14"
CPU_1MIN = "1.3.6.1.4.1.9.9.109.1.1.1.1.7.1"
MEMORY_USED = "1.3.6.1.4.1.9.9.48.1.1.1.5.1"
MEMORY_FREE = "1.3.6.1.4.1.9.9.48.1.1.1.6.1"
MEMORY_TOTAL = 2359986044
ERRORS = ["1.3.6.1.2.1.2.2.1.14." + UPLINK, "1.3.6.1.2.1.2.2.1.20." + UPLINK]
DISCARDS = ["1.3.6.1.2.1.2.2.1.13." + UPLINK, "1.3.6.1.2.1.2.2.1.19." + UPLINK]
FC_PORT = "16777216"
FC_ERRORS = [
    "1.3.6.1.4.1.9.9.289.1.2.1.1.5." + FC_PORT,
    "1.3.6.1.4.1.9.9.289.1.2.1.1.6." + FC_PORT,
    "1.3.6.1.4.1.9.9.289.1.2.1.1.26." + FC_PORT,
]


async def request(command, community, objects):
    target = await UdpTransportTarget.create(("127.0.0.1", 161))
    error, status, _, result = await command(SnmpEngine(), CommunityData(community), target, ContextData(), *objects)
    if error or status:
        sys.exit("%s: %s" % (community, error or status.prettyPrint()))
    return [int(value) for _, value in result]


async def get(community, *oids):
    return await request(get_cmd, community, [ObjectType(ObjectIdentity(oid)) for oid in oids])


async def put(community, *pairs):
    await request(set_cmd, community, [ObjectType(ObjectIdentity(oid), value) for oid, value in pairs])


async def increase(device, oids, minutes):
    print("Adding to %s on %s every 10 seconds for %d minutes" % (", ".join(oids), device, minutes))
    end = time.time() + minutes * 60
    while time.time() < end:
        values = await get(device, *oids)
        await put(device, *[(oid, Counter32((value + 5) % 2**32)) for oid, value in zip(oids, values)])
        await asyncio.sleep(10)


def memory(percent):
    used = MEMORY_TOTAL * percent // 100
    return put(LAB, (MEMORY_USED, Gauge32(used)), (MEMORY_FREE, Gauge32(MEMORY_TOTAL - used)))


COMMANDS = {
    "interface-down": lambda which: put(LAB, (IF_OPER_STATUS + INTERFACES[which], Integer32(2))),
    "interface-up": lambda which: put(LAB, (IF_OPER_STATUS + INTERFACES[which], Integer32(1))),
    "reboot": lambda: put(LAB, (SYS_UPTIME, TimeTicks(6000))),
    "fru-fail": lambda: put(FRU, (FRU_POWER_STATUS, Integer32(8))),
    "fru-on": lambda: put(FRU, (FRU_POWER_STATUS, Integer32(2))),
    "cpu-high": lambda: put(LAB, (CPU_1MIN, Gauge32(95))),
    "cpu-normal": lambda: put(LAB, (CPU_1MIN, Gauge32(3))),
    "memory-high": lambda: memory(95),
    "memory-normal": lambda: put(LAB, (MEMORY_USED, Gauge32(88360644)), (MEMORY_FREE, Gauge32(2271625400))),
    "errors": lambda minutes="20": increase(LAB, ERRORS, int(minutes)),
    "drops": lambda minutes="35": increase(LAB, DISCARDS, int(minutes)),
    "fc-errors": lambda minutes="20": increase(FC, FC_ERRORS, int(minutes)),
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        sys.exit(__doc__)
    try:
        action = COMMANDS[sys.argv[1]](*sys.argv[2:])
    except (KeyError, TypeError, ValueError):
        sys.exit(__doc__)
    asyncio.run(action)
