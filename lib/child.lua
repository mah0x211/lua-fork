--
-- Copyright (C) 2024 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
local find = string.find
local type = type
local getpid = require('getpid')
local signal = require('signal')
local kill = signal.kill
local waitpid = require('waitpid')

--- @class fork.child
--- @field cpid integer
local Child = {}

--- init
--- @param pid integer
function Child:init(pid)
    self.cpid = pid
    return self
end

--- is_child
--- @return boolean
function Child:is_child()
    return false
end

--- pid
--- @return integer pid
function Child:pid()
    return self.cpid
end

--- ppid
--- @return integer ppid
function Child:ppid()
    return getpid()
end

--- waitpid
--- @param sec? number
--- @param ... string
---| 'untraced' # WUNTRACED
---| 'continued' # WCONTINUED
--- @return table? result
--- @return any err
--- @return boolean? timeout
function Child:waitpid(sec, ...)
    if self.cpid > 0 then
        local res, err, again = waitpid(self.cpid, sec, ...)
        if res then
            self.cpid = -self.cpid
        end
        return res, err, again
    end
end

--- waitpid calls waitpid method without timeout
--- @param ... string
---| 'untraced' # WUNTRACED
---| 'continued' # WCONTINUED
--- @return table? result
--- @return any err
--- @return boolean? timeout
function Child:wait(...)
    return self:waitpid(nil, ...)
end

--- constants
local EINVAL = require('errno').EINVAL
local ESRCH = require('errno').ESRCH
local is_error = require('error.is')
local SIGTERM = signal.SIGTERM
local VALID_SIGNALS = {}
for k, v in pairs(signal) do
    if find(k, '^SIG%w+$') then
        VALID_SIGNALS[k], VALID_SIGNALS[v] = v, v
    end
end

--- kill
--- @param sig? string|integer
--- @return boolean ok
--- @return any err
function Child:kill(sig)
    assert(sig == nil or type(sig) == 'string' or type(sig) == 'number',
           'sig must be string or integer')

    local signo = SIGTERM
    if sig then
        signo = sig == '0' and 0 or VALID_SIGNALS[sig]
        if not signo then
            return false, EINVAL:new('invalid signal')
        end
    end

    if self.cpid < 1 then
        -- already exited
        return false
    end

    local ok, err = kill(signo, self.cpid)
    if is_error(err, ESRCH) then
        self.cpid = -self.cpid
        err = nil
    end
    return ok, err
end

Child = require('metamodule').new(Child)

return Child
