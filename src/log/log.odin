package log

import "core:fmt"
import "core:strings"
import "core:os"
import "core:sys/unix"
import win "core:sys/windows"

import "../ext"

Level_Headers := [?]string{
    "[TRACE]",
    "[DEBUG]",
    "[INFO ]",
    "[WARN ]",
    "[ERROR]",
    "[FATAL]",
}

Level :: enum {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
    Fatal,
}

@private
_log_to_console: bool = true

@private
_log_to_file: bool = true

@private
_file_handle: os.Handle

init :: proc(log_to_file, log_to_console: bool) {
    if log_to_file {
        if _file_handle == 0 {
            _create_log_file()
        }
    }
    else if _file_handle != 0 {
        _close_log_file()
    }
}

trace :: proc(args: ..any) {
    _write(level=.Trace, args=args)
}

debug :: proc(args: ..any) {
    _write(level=.Debug, args=args)
}

info :: proc(args: ..any) {
    _write(level=.Info, args=args)
}

warn :: proc(args: ..any) {
    _write(level=.Warn, args=args)
}

error:: proc(args: ..any, location := #caller_location) {
    _write(level=.Error, args=args, location=location)
}

fatal :: proc(args: ..any, location := #caller_location) {
    _write(level=.Fatal, args=args, location=location)
    panic("", location)
}

@private
_format_message :: proc(level: Level, args: ..any, location := #caller_location) -> string {
    when ODIN_OS == .Windows {
        t: win.SYSTEMTIME
        ext.GetLocalTime(&t)
    
        prefix := fmt.tprintf("%2d:%2d:%2d.%3d %s: ", 
            t.hour, t.minute, t.second, t.milliseconds, Level_Headers[level])
    }
    when ODIN_OS == .Linux {
        t: unix.timespec
        unix.clock_gettime(unix.CLOCK_BOOTTIME, &t)
        
        prefix := fmt.tprintf("%d:%3d %s: ", 
            t.tv_sec, t.tv_nsec / 1000000, Level_Headers[level])
    }

    message := fmt.tprint(args=args, sep="")

    if level == .Error || level == .Fatal {
        return fmt.tprintf("%s%s(%d:%d)[%s] %s\n", 
        prefix, location.file_path, location.line, location.column, location.procedure, message)
    }
    else {
        return fmt.tprintf("%s%s\n", prefix, message)
    }
}

@private
_write :: proc(level: Level, args: ..any, location := #caller_location) {
    if !_log_to_console && !_log_to_file { return }
    
    formatted_message := _format_message(level=level, args=args, location=location)

    if _file_handle == 0 && _log_to_file {
        _create_log_file()
    }

    if _log_to_console {
        fmt.print(formatted_message)
    }
    if _log_to_file {
        _write_to_file(formatted_message)
    }
}

@private
_get_log_file_path :: proc() -> string {
    when ODIN_OS == .Windows {
        FILE_PATH_MAX :: 300
        data: [FILE_PATH_MAX]byte
        
        file_path: string
            
        res := ext.GetModuleFileNameA(cast(win.HMODULE)nil, transmute(win.LPSTR)&data, FILE_PATH_MAX)

        if win.GetLastError() != 0 {
            fmt.print(_format_message(.Warn, "Unable to locate exe, falling back to current directory"))
            file_path = string(os.get_current_directory())
        }
        else {
            file_path = string(data[:])
            file_path = file_path[:strings.last_index(file_path, "\\")]
        }
        
        return fmt.tprintf("%s\\log.txt", file_path)
    }
    else when ODIN_OS == .Linux {
        file_path := string(os.get_current_directory())
        return fmt.tprintf("%s/log.txt", file_path)
    }
}

@private
_write_to_file :: proc(message: string) {
    if _file_handle == 0 {
        _create_log_file()
    }
    
    if !_log_to_file { return }

    _, err := os.write_string(_file_handle, message)
    if err != os.ERROR_NONE {
        _log_to_file = false
        _write(Level.Error, "Failure to write string to file, disabling log to file")
        return
    }
    
    when ODIN_OS == .Windows {
        err = os.flush(_file_handle)
    }
    when ODIN_OS == .Linux {
        unix.sys_fsync(int(_file_handle))
    }
    if err != os.ERROR_NONE {
        _log_to_file = false
        _write(Level.Error, "Failure to flush string to file, disabling log to file")
    }
}

@private
_create_log_file :: proc() {    
    file_path := _get_log_file_path()
    
    err: os.Errno
    _file_handle, err = os.open(file_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC)

    if err != 0 {
        _log_to_file = false
        fmt.print(_format_message(level=.Error, args={"Unable to create log file at \"", file_path, "\", disabling log to file"}))
        return
    }
    fmt.print(_format_message(.Info, "Logging to ", file_path))
}

@private
_close_log_file :: proc() {
    err := os.close(_file_handle)
    if err != os.ERROR_NONE { 
        fmt.print(_format_message(.Error, "Unable to close file"))
    }
    else {
        _file_handle = 0
    }
}