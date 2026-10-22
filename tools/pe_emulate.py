#!/usr/bin/env python3
"""
pe_emulate.py - runs a Windows x64 console program (PE32+) in a CPU emulator, with the few Win32
calls a Dhar program uses (GetStdHandle, WriteFile, ReadFile, ExitProcess) implemented in Python.

    python3 tools/pe_emulate.py prog.exe [--stdin TEXT]
    prints the program's stdout, writes its stderr to stderr, and exits with the program's exit code.

Why this exists: Stage 0's Windows output could not be run on a real Windows machine while it was
being written. This tool checks the machine code itself (the compiled instructions, the Dhar runtime
stub, and the imports) and enforces the Win64 calling rules that matter: the stack must be 16-byte
aligned at every Win32 call. It does NOT test the Windows loader, so a run on real Windows is still the
final proof. Needs: pip install unicorn pefile
"""
import argparse
import sys

import pefile
from unicorn import Uc, UC_ARCH_X86, UC_MODE_64, UC_HOOK_CODE, UcError
from unicorn.x86_const import (UC_X86_REG_RAX, UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8,
                               UC_X86_REG_R9, UC_X86_REG_RSP, UC_X86_REG_RIP)

API_BASE = 0x7F000000
STACK_TOP = 0x7FFF0000
STACK_SIZE = 0x100000
SENTINEL = 0x7E000000          # return address of the entry point
MAX_INSN = 50_000_000


def run(path, stdin=b""):
    pe = pefile.PE(path)
    base = pe.OPTIONAL_HEADER.ImageBase
    size = (pe.OPTIONAL_HEADER.SizeOfImage + 0xFFF) & ~0xFFF
    if base + size >= 1 << 32 and pe.OPTIONAL_HEADER.DllCharacteristics & 0x40:
        raise SystemExit("image is relocatable above 4 GB; Stage 0 output needs a fixed low base")
    mu = Uc(UC_ARCH_X86, UC_MODE_64)
    mu.mem_map(base, size)
    mu.mem_write(base, pe.header[:pe.OPTIONAL_HEADER.SizeOfHeaders])
    for s in pe.sections:
        data = s.get_data()
        mu.mem_write(base + s.VirtualAddress, data[:max(s.Misc_VirtualSize, len(data))])
    mu.mem_map(STACK_TOP - STACK_SIZE, STACK_SIZE)
    mu.mem_map(API_BASE, 0x1000)
    mu.mem_map(SENTINEL, 0x1000)

    # point every import-address-table slot at a stub address we trap
    names = {}
    for entry in pe.DIRECTORY_ENTRY_IMPORT:
        for i, imp in enumerate(entry.imports):
            addr = API_BASE + 16 * len(names)
            names[addr] = imp.name.decode()
            mu.mem_write(imp.address - base + base, addr.to_bytes(8, "little"))
    state = {"out": bytearray(), "err": bytearray(), "stdin": bytearray(stdin), "exit": None, "calls": 0}
    handles = {-10: 0x10, -11: 0x11, -12: 0x12}

    def ret(mu_, value):
        rsp = mu_.reg_read(UC_X86_REG_RSP)
        mu_.reg_write(UC_X86_REG_RAX, value & 0xFFFFFFFFFFFFFFFF)
        mu_.reg_write(UC_X86_REG_RIP, int.from_bytes(mu_.mem_read(rsp, 8), "little"))
        mu_.reg_write(UC_X86_REG_RSP, rsp + 8)

    def hook(mu_, address, size_, _ud):
        if address in names:
            rsp = mu_.reg_read(UC_X86_REG_RSP)
            if rsp % 16 != 8:                       # after the call pushed its return address
                raise SystemExit("Win64 ABI violation: stack not 16-byte aligned at call to " + names[address])
            n = names[address]
            rcx, rdx, r8, r9 = (mu_.reg_read(r) for r in (UC_X86_REG_RCX, UC_X86_REG_RDX, UC_X86_REG_R8, UC_X86_REG_R9))
            state["calls"] += 1
            if n == "GetStdHandle":
                n32 = rcx & 0xFFFFFFFF
                ret(mu_, handles.get(n32 - (1 << 32), 0xFFFFFFFFFFFFFFFF))
            elif n == "WriteFile":
                buf = bytes(mu_.mem_read(rdx, r8 & 0xFFFFFFFF))
                (state["out"] if rcx == 0x11 else state["err"] if rcx == 0x12 else bytearray()).extend(buf)
                mu_.mem_write(r9, (len(buf)).to_bytes(4, "little"))
                ret(mu_, 1)
            elif n == "ReadFile":
                take = bytes(state["stdin"][:r8 & 0xFFFFFFFF]); del state["stdin"][:len(take)]
                mu_.mem_write(rdx, take); mu_.mem_write(r9, len(take).to_bytes(4, "little"))
                ret(mu_, 1)
            elif n == "ExitProcess":
                state["exit"] = rcx & 0xFFFFFFFF
                mu_.emu_stop()
            else:
                raise SystemExit("program called an API the emulator does not implement: " + n)
        elif address == SENTINEL:
            state["exit"] = state["exit"] if state["exit"] is not None else 0
            mu_.emu_stop()

    mu.hook_add(UC_HOOK_CODE, hook)
    sp = STACK_TOP - 0x1000
    sp -= 8
    mu.mem_write(sp, SENTINEL.to_bytes(8, "little"))   # entry is called like a function
    mu.reg_write(UC_X86_REG_RSP, sp)
    try:
        mu.emu_start(base + pe.OPTIONAL_HEADER.AddressOfEntryPoint, SENTINEL, count=MAX_INSN)
    except UcError as e:
        rip = mu.reg_read(UC_X86_REG_RIP)
        raise SystemExit("emulation fault: %s at rip=0x%x" % (e, rip))
    return state


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("exe")
    ap.add_argument("--stdin", default="")
    a = ap.parse_args()
    st = run(a.exe, a.stdin.encode())
    sys.stdout.buffer.write(bytes(st["out"]))
    sys.stderr.buffer.write(bytes(st["err"]))
    return st["exit"] or 0


if __name__ == "__main__":
    sys.exit(main())
