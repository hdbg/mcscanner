import winim
import winim/winstr

import chronicles

import std/[unicode, strutils]

template safeCallBool(message: static string, expression) =
  if expression == FALSE:
    error message, code=GetLastError()
    quit()

proc remoteRead[T](h: HANDLE, address: pointer): T = 
  zeroMem addr result, sizeof T
  var readedBytes: SIZE_T

  if ReadProcessMemory(h, cast[LPCVOID](address), cast[LPVOID](addr result), (sizeof T).SIZE_T, addr readedBytes) == 0.BOOL:
    let err = GetLastError()
    error "rpm", code=err
  assert readedBytes == sizeof T

proc remoteRead[T](h: HANDLE, address: pointer, value: var T) = 
  zeroMem addr value, sizeof T
  var readedBytes: SIZE_T

  if ReadProcessMemory(h, cast[LPCVOID](address), cast[LPVOID](addr value), (sizeof T).SIZE_T, addr readedBytes) == 0.BOOL:
    let err = GetLastError()
    error "rpm", code=err
  assert readedBytes == sizeof T

proc fixStr(h: Handle, x: UnicodeString): string = 
  var unicodeBuffer = allocShared0(sizeof(WCHAR) * x.MaximumLength.int)

  var readedBytes: SIZE_T
  ReadProcessMemory(h, cast[LPCVOID](x.Buffer), cast[LPVOID](unicodeBuffer), (sizeof(WCHAR) * x.Length.int).SIZE_T, addr readedBytes)

  assert readedBytes == (sizeof(WCHAR) * x.Length.int).SIZE_T

  let 
    rebuildedString = UnicodeString(
      Length: x.Length, 
      MaximumLength: x.MaximumLength, 
      Buffer: cast[type(x.Buffer)](unicodeBuffer)
    )
    rawUtf8 = allocShared0((x.MaximumLength.int * 2) + 1)

  let convResult = WideCharToMultiByte(
    CP_UTF8,
    WC_ERR_INVALID_CHARS,
    rebuildedString.Buffer,
    rebuildedString.Length.int32,
    cast[LPSTR](rawUtf8),
    x.MaximumLength.int32,
    NULL,
    NULL 
  )

  # if convResult == 0:
  #   let code = GetLastError()
  #   error "conv", code=code

  # for i in 0..<int(x.Length):
  #   let charAddr = cast[ptr uint8](cast[uint](rawUtf8) + i.uint)
  #   result.add chr(charAddr[])

  result = $(cast[ptr char](rawUtf8))

  deallocShared(rawUtf8)
  deallocShared(rebuildedString.Buffer)

proc isMinecraft(p: HANDLE): bool = 
  var 
    procBasicInfo: PROCESS_BASIC_INFORMATION
    procEnv: PEB
    procParams: RTL_USER_PROCESS_PARAMETERS

  zeroMem(addr procBasicInfo, sizeof(procBasicInfo))

  let queryResult = int NtQueryInformationProcess(
    p,
    0.ProcessInformationClass,
    addr procBasicInfo,
    (sizeof procBasicInfo).ULONG,
    cast[PULONG](0)
  )

  if queryResult != 0:
    let err = GetLastError()
    error "NtQuery", code=err
    return false
  
  # echo "PEB: ", cast[uint](procBasicInfo.PebBaseAddress).toHex, " PID: ", cast[uint](procBasicInfo.UniqueProcessId)

  p.remoteRead(cast[pointer](procBasicInfo.PebBaseAddress), procEnv)

  # echo procEnv

  p.remoteRead(cast[pointer](procEnv.ProcessParameters), procParams)

  # echo procParams

  # echo "ImagePathName: ", 
  # echo "CommandLine: ", 

  let 
    imagePath = fixStr(p, procParams.ImagePathName)
    cmdLine = fixStr(p, procParams.CommandLine)

  let
    vmName: bool = imagePath.contains "javaw.exe"
    mc: bool = cmdLine.contains "minecraft"
    mojang: bool = cmdLine.contains "mojang"

  return vmName and mc and mojang

# proc findMinecraft = 
proc findMinecraft*(): seq[PROCESSENTRY32]  =
  let hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPALL, 0)

  var procEntry: PROCESSENTRY32
  procEntry.dwSize = DWORD sizeof procEntry

  safeCallBool("process32First", Process32First(hSnapshot, &procEntry))

  # $$ doesn't delete \0
  while true:
    let hProc = OpenProcess(PROCESS_ALL_ACCESS, false, procEntry.th32ProcessID)
    if hProc != 0: # NULL
      if hProc.isMinecraft:
        result.add procEntry
      discard CloseHandle(hProc)

    if Process32Next(hSnapshot, &procEntry) == FALSE: break
  
  discard CloseHandle(hSnapshot)