import winim
import locator, mem

import chronicles
import std/[options, segfaults, terminal]

const
  workersCount = 8
  percentLog = 1

proc interrupt(msg: string) = 
  echo msg
  discard stdin.readChar
  quit()

proc validAddresses(mcProc: ProcessEntry32): seq[tuple[first, last: uint]] =
  let hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, mcProc.th32ProcessID)

  var dumpAddr: uint = 0
  var regionInfo: MemoryBasicInformation

  while VirtualQueryEx(hProc, cast[LPCVOID](dumpAddr), addr regionInfo, (sizeof MemoryBasicInformation).SIZE_T) != 0:
    let 
      regBase = cast[uint](regionInfo.BaseAddress)
      regSize = uint(regionInfo.RegionSize)

    dumpAddr += regSize

    if regionInfo.State != 0x1000: 
      # error "MEM_COMMIT", add=toHex(dumpAddr)
      continue
    if regionInfo.Type != MEM_PRIVATE: 
      # error "MEM_PRIVATE", add=toHex(dumpAddr)
      continue
    if regionInfo.Protect == PAGE_NOACCESS:
      # error "noacc", add=toHex(dumpAddr)
      continue

    
    result.add (first: regBase, last: regBase + regSize)

    # debug "dumpAddr", a=toHex(dumpAddr)


  discard hproc.CloseHandle

proc getProcBase(h: Handle): uint = 
  var 
    modules: array[128, HModule]
    requiredBytes: int32

  if EnumProcessModules(h, addr modules[0], sizeof(modules).int32, addr requiredBytes) == 0:
    error "EnumProcessModules"
    interrupt "Press F"

  cast[uint](modules[0])


proc scanMinecraft(mcProc: ProcessEntry32): Option[string] =
  var 
    tasks = mcProc.validAddresses()
    workers: array[workersCount, Thread[mem.ScanThreadInfo]]
    chan = cast[ptr Channel[string]](allocShared0(sizeof Channel[string]))
    killChan = cast[ptr Channel[bool]](allocShared0(sizeof Channel[bool]))

  let originalSize = len tasks

  chan[].open()
  killChan[].open()

  proc update(): bool = 
    result = true

    for w in workers.mitems:
      if not w.running:
        if tasks.len > 0:
          let info = mem.ScanThreadInfo(region: tasks[0], chan: chan, mcProc: mcProc, killChan: killChan)

          createThread(w, mem.chunkScan, info)
          tasks.delete 0

          result = true
        else:
          result = false

        when percentLog != 0:
          let percent = (tasks.len div originalSize)
          if percent mod percentLog == 0 and percent != 0:
            info "percentfinished", p=percent
  
  discard update()

  proc killThreads =
    for i in 0..workersCount:
      killChan[].send(true) 


  while true:
    for w in workers.mitems:
      if not w.running:
        let msg = chan[].tryRecv

        if msg.dataAvailable:
          stdout.styledWriteLine fgRed, "HACK Detected! ", fgYellow, msg.msg
          killThreads()
          interrupt ""
        
        if not update():
          stdout.styledWriteLine fgGreen, "Target clear!"
          killThreads()
          interrupt ""


when isMainModule:
  let vms = locator.findMinecraft()

  if vms.len == 0: interrupt "No minecraft found!"

  for p in vms: discard p.scanMinecraft()

