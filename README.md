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

- `p:fork.process|fork.child`: parent process will get `fork.child` object, and child process will get `fork.process` object.
- `err:any`: `nil` on success, or error object on failure.
- `again:boolean`: true if `errno` is `EAGAIN`.

**Example**

```lua
local fork = require('fork')

local p = assert(fork())
if p:is_child() then
    print('child process', p, p:pid(), 'parent:', p:ppid())
    os.exit(123)
end

print('parent process', p, p:ppid(), 'child:', p:pid())
local dump = require('dump')
local res = assert(p:waitpid())
print('child process terminated:', dump(res))
--
-- parent process	fork.child: 0x600003c98f80	49632	child:	49633
-- child process	fork.process: 0x146705ab0	49633	parent:	49632
-- child process terminated:	{
--     exit = 123,
--     pid = 49633
-- }
--
```

## Common Methods

## ok = p:is_child()

returns `true` if the current-process is a child-process.

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


## ok, err = p:kill( [signo] )

send a signal to the process.

**Parameters**

- `signo:integer`: signal number. default `SIGTERM`.

**Returns**

- `ok:boolean`: `true` on success.
- `err:any`: `nil` and `ok` is `false` on process not found, or error object on failure.


## `fork.child` Methods

## res, err, timeout = child:waitpid( [sec [, ...]] )

wait for process termination by https://github.com/mah0x211/lua-waitpid module.  

**Parameters**

- `sec:integer`: timeout seconds. default `nil`.
- `...:string`: wait options;  
    - `'nohang'`: return immediately if no child has exited. if this option is specified, `sec` is ignored.
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
- `timeout:boolean`: `true` if timed out.


## res, err, again = child:wait( ... )

wait for process termination.  
this is equivalent to `p:waitpid( nil, ... )`.


