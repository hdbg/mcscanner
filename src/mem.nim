import std/[options, tables, sets, strutils, strformat]
import signatures
import winim
import chronicles

type 
  MemChunk* = tuple[first, last: uint]
  ScanThreadInfo* = object
    region*: MemChunk
    chan*: ptr Channel[string]
    killChan*: ptr Channel[bool]
    mcProc*: ProcessEntry32

const 
  chunkSize = sizeof(char) * 65536

  optimizedSet = block:
    var result: HashSet[string]

    for (categoryName, categorySigs) in signatures.allSigs.pairs():
      for (subCategoryName, subCategorySigs) in categorySigs.pairs():
        result.incl subCategorySigs

    result

proc sigFind(x: string): Option[string] = 
  if not optimizedSet.contains(x): return none(string)

  for (categoryName, categorySigs) in signatures.allSigs.pairs():
    for (subCategoryName, subCategorySigs) in categorySigs.pairs():
      if subCategorySigs.contains(x.strip):
        result = some(&"{categoryName}/{subCategoryName}")

proc chunkScan*(info: ScanThreadInfo) {.thread.} =
  let hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, info.mcProc.th32ProcessID)

  var 
    lastString: string
    memChunk = alloc0(chunkSize)

  proc close = 
    memchunk.dealloc
    discard hproc.CloseHandle 

  for chunk in countup(info.region.first, info.region.last, chunkSize):
      if info.killChan[].tryRecv().dataAvailable:
        close()
        return

      let
        bytesRead: SIZE_T = -1
        isRead = ReadProcessMemory(
          hProc, cast[LPCVOID](chunk), 
          memChunk, 
          chunkSize.SIZE_T, 
          unsafeAddr bytesRead
        )
      if isRead == 0:
        let code = GetLastError()
        #[if code != 299:]# 
        # error "readProcMem", code=code, c=chunk.toHex
        continue

      # info "chunk", c=toHex(chunk)
        
      for characterIndex in 0..<bytesRead:
        let seeked = cast[ptr char](cast[int](memChunk) + characterIndex)[]
        if seeked == '\0' or seeked == '\x00':
          # debug "str", l=lastString, `block`=tohex(chunk)
          let result = lastString.sigFind
          if result.isSome:
            info.chan[].send result.get

            # info "sent", m=result.get
            close()
            return
          lastString.setLen 0
        else:
          lastString &= $seeked

  return