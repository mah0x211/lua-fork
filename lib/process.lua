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
local getpid = require('getpid')
local signal = require('signal')

--- @class fork.process
local Process = {}

--- init
--- @return fork.process
function Process:init()
    return self
end

--- is_child
--- @return boolean
function Process:is_child()
    return true
end

--- pid
--- @return integer pid
function Process:pid()
    return getpid()
end

--- ppid
--- @return integer ppid
function Process:ppid()
    return getpid(true)
end

--- constants
local EINVAL = require('errno').EINVAL
local SIGTERM = signal.SIGTERM
local raise = signal.raise
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
function Process:kill(sig)
    assert(sig == nil or type(sig) == 'string' or type(sig) == 'number',
           'sig must be string or integer')

    local signo = SIGTERM
    if sig then
        signo = VALID_SIGNALS[sig]
        if not signo then
            return false, EINVAL:new('invalid signal')
        end
    end
    return raise(signo)
end

Process = require('metamodule').new(Process)

return Process
