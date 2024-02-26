# lua-fork

[![test](https://github.com/mah0x211/lua-fork/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-fork/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-fork/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-fork)


create a new process.

## Installation

```sh
luarocks install fork
```

## Error Handling

the functions/methods are return the error object created by https://github.com/mah0x211/lua-errno module.

## p, err, again = fork()

create child process.

**Returns**

- `p:fork.process`: `fork.process` object.
- `err:any`: `nil` on success, or error object on failure.
- `again:boolean`: true if `errno` is `EAGAIN`.


## ok = p:is_child()

returns `true` if the process is a child-process.

**Returns**

- `ok:boolean`: `true` on child-process.


## pid = p:pid()

get process id.

**Returns**

- `pid:integer`: process id.


## pid = p:ppid()

get parent process id.

**Returns**

- `pid:integer`: parent process id.


## res, err, again = p:waitpid( [sec [, ...]] )

wait for process termination by https://github.com/mah0x211/lua-waitpid module.  

**Parameters**

- `sec:integer`: timeout seconds. default `nil`.
- `...:string`: wait options;  
    - `'nohang'`: return immediately if no child has exited.
    - `'untraced'`: also return if a child has stopped.
    - `'continued'`: also return if a stopped child has been resumed by delivery of `SIGCONT`.

**Returns**

- `res:table`: result table if succeeded.
    - `pid:integer` = process id.
    - `exit:integer` = value of `WEXITSTATUS` if `WIFEXITED` is true.
    - `sigterm:integer` = value of `WTERMSIG` if `WIFSIGNALED` is true.
    - `sigstop:integer` = value of `WSTOPSIG` if `WIFSTOPPED` is true.
    - `sigcont:boolean` = `true` if `WIFCONTINUED` is true
- `err:any`: `nil` on success, or error object on failure.
- `again:boolean`: `true` if `waitpid` returns `0`.


## res, err, again = p:wait( ... )

wait for process termination.  
it is equivalent to `p:waitpid( nil, ... )`.


## ok, err = child:kill( [signo] )

send a signal to the process.

**Parameters**

- `signo:integer`: signal number. default `SIGTERM`.

**Returns**

- `ok:boolean`: `true` on success.
- `err:any`: `nil` and `ok` is `false` on process not found, or error object on failure.

