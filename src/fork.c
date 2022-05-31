/**
 *  Copyright (C) 2014 Masatoshi Teruya
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
 *
 *  tmpl/process_tmpl.c
 *  lua-process
 *
 *  Created by Masatoshi Teruya on 14/03/27.
 */

#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
// lua
#include <lua_errno.h>

#define FORK_PROC_MT "fork.process"

static inline int checkoptions(lua_State *L, int index)
{
    static const char *const options[] = {
        "nohang",
        "untraced",
        "continued",
        NULL,
    };
    int top  = lua_gettop(L);
    int opts = 0;

    for (; index <= top; index++) {
        switch (luaL_checkoption(L, index, NULL, options)) {
        case 0:
            opts |= WNOHANG;
            break;

        case 1:
            opts |= WUNTRACED;
            break;

        default:
#ifdef WCONTINUED
            opts |= WCONTINUED;
#endif
            break;
        }
    }

    return opts;
}

static int waitpid_lua(lua_State *L, pid_t *p, int opts)
{
    pid_t pid   = *p;
    int wstatus = 0;

    // pid field does not exists
    if (pid < 1) {
        lua_pushnil(L);
        errno = ECHILD;
        lua_errno_new(L, errno, "wait");
        return 2;
    }

    switch (waitpid(pid, &wstatus, opts)) {
    case -1:
        // got error
        lua_pushnil(L);
        lua_errno_new(L, errno, "waitpid");
        return 2;

    case 0:
        // nonblock = WNOHANG
        lua_pushnil(L);
        lua_pushnil(L);
        lua_pushboolean(L, 1);
        return 3;
    }

    // push result
    lua_createtable(L, 0, 5);
    lauxh_pushint2tbl(L, "pid", pid);
    if (WIFEXITED(wstatus)) {
        *p = -pid;
        // exit status
        lauxh_pushint2tbl(L, "exit", WEXITSTATUS(wstatus));
    } else if (WIFSIGNALED(wstatus)) {
        *p = -pid;
        // exit by signal
        lauxh_pushint2tbl(L, "sigterm", WTERMSIG(wstatus));
#ifdef WCOREDUMP
        if (WCOREDUMP(wstatus)) {
            lauxh_pushbool2tbl(L, "coredump", 1);
        }
#endif
    } else if (WIFSTOPPED(wstatus)) {
        // stopped by signal
        lauxh_pushint2tbl(L, "sigstop", WSTOPSIG(wstatus));
    } else if (WIFCONTINUED(wstatus)) {
        // continued by signal
        lauxh_pushbool2tbl(L, "sigcont", 1);
    }

    return 1;
}

static inline pid_t *checknochild(lua_State *L, const char *errmsg)
{
    pid_t *p = luaL_checkudata(L, 1, FORK_PROC_MT);
    if (*p == 0) {
        luaL_error(L, errmsg);
    }
    return p;
}

static int wait_lua(lua_State *L)
{
    pid_t *p = checknochild(L, "cannot wait for own-process termination");
    int opts = checkoptions(L, 2);
    return waitpid_lua(L, p, opts);
}

static int kill_lua(lua_State *L)
{
    pid_t *p  = checknochild(L, "cannot kill own-process");
    int signo = (int)lauxh_optinteger(L, 2, SIGTERM);
    int opts  = checkoptions(L, 3);
    pid_t pid = *p;

    lua_settop(L, 1);

    // pid already exit
    if (pid < 1) {
        lua_pushnil(L);
        errno = ESRCH;
        lua_errno_new(L, errno, "kill");
        return 2;
    } else if (kill(pid, signo) == -1) {
        // got error
        if (errno == ESRCH) {
            *p = -pid;
        }
        lua_pushnil(L);
        lua_errno_new(L, errno, "kill");
        return 2;
    }

    return waitpid_lua(L, p, opts);
}

static int pid_lua(lua_State *L)
{
    pid_t *p  = luaL_checkudata(L, 1, FORK_PROC_MT);
    pid_t pid = *p;

    if (pid == 0) {
        pid = getpid();
    }
    lua_pushinteger(L, pid);
    return 1;
}

static int is_child_lua(lua_State *L)
{
    pid_t *p = luaL_checkudata(L, 1, FORK_PROC_MT);
    lua_pushboolean(L, *p == 0);
    return 1;
}

static int gc_lua(lua_State *L)
{
    pid_t *p  = luaL_checkudata(L, 1, FORK_PROC_MT);
    pid_t pid = *p;

    if (pid > 1) {
        // kill process
        if (waitpid(pid, NULL, WNOHANG) == 0 && kill(pid, SIGKILL) == 0) {
            waitpid(pid, NULL, WNOHANG | WUNTRACED);
        }
    }

    return 0;
}

static int tostring_lua(lua_State *L)
{
    pid_t *p = luaL_checkudata(L, 1, FORK_PROC_MT);
    lua_pushfstring(L, FORK_PROC_MT ": %p", p);
    return 1;
}

static int fork_lua(lua_State *L)
{
    pid_t *p  = lua_newuserdata(L, sizeof(pid_t));
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

    *p = pid;
    lauxh_setmetatable(L, FORK_PROC_MT);
    return 1;
}

LUALIB_API int luaopen_fork(lua_State *L)
{
    struct luaL_Reg mmethod[] = {
        {"__gc",       gc_lua      },
        {"__tostring", tostring_lua},
        {NULL,         NULL        }
    };
    struct luaL_Reg method[] = {
        {"is_child", is_child_lua},
        {"pid",      pid_lua     },
        {"wait",     wait_lua    },
        {"kill",     kill_lua    },
        {NULL,       NULL        }
    };

    lua_errno_loadlib(L);

    // create metatable
    luaL_newmetatable(L, FORK_PROC_MT);
    // metamethods
    for (struct luaL_Reg *ptr = mmethod; ptr->name; ptr++) {
        lauxh_pushfn2tbl(L, ptr->name, ptr->func);
    }
    // methods
    lua_pushstring(L, "__index");
    lua_newtable(L);
    for (struct luaL_Reg *ptr = method; ptr->name; ptr++) {
        lauxh_pushfn2tbl(L, ptr->name, ptr->func);
    }
    lua_rawset(L, -3);
    lua_pop(L, 1);

    // create module table
    lua_pushcfunction(L, fork_lua);

    return 1;
}
