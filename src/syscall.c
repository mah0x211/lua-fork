/**
 *  Copyright (C) 2014-present Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
// lua
#include <lua_errno.h>

static int fork_lua(lua_State *L)
{
    pid_t pid = fork();

    if (pid == -1) {
        // got error
        lua_pushnil(L);
        if (errno == EAGAIN) {
            lua_pushnil(L);
            lua_pushboolean(L, 1);
            return 3;
        }
        lua_errno_new(L, errno, "fork");
        return 2;
    }

    lua_pushinteger(L, pid);
    return 1;
}

LUALIB_API int luaopen_fork_syscall(lua_State *L)
{
    lua_errno_loadlib(L);
    lua_pushcfunction(L, fork_lua);
    return 1;
}
