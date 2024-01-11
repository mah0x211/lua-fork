local fork = require('fork')
local assert = require('assert')
local errno = require('errno')
local signal = require('signal')
local sleep = require('time.sleep')
local getpid = require('getpid')

local function test_fork()
    -- test that fork child process
    local pid = assert(getpid())
    local ppid = assert(getpid(true))
    local p = assert(fork())
    if p:is_child() then
        assert.greater(p:pid(), pid)
        assert.equal(p:ppid(), pid)
        os.exit()
    else
        assert.match(p, '^fork.process: ', false)
        assert.greater(p:pid(), pid)
        assert.equal(p:ppid(), ppid)
    end
end

local function test_wait()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123
        os.exit(123)
    end
    local pid = p:pid()

    -- test that child process exit with code 123
    local res, err = assert(p:wait())
    assert.equal(res, {
        pid = pid,
        exit = 123,
    })
    assert.is_nil(err)

    -- test that pid will be negative integer after exit
    assert.equal(p:pid(), -pid)

    -- test that return error after exit
    res, err = p:wait()
    assert.is_nil(res)
    assert.equal(err.type, errno.ECHILD)
end

local function test_wait_nohang()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123 after 500ms
        sleep(0.5)
        os.exit(123)
    end
    local pid = p:pid()

    -- test that return again=true
    local res, werr, again = p:wait('nohang')
    assert.is_nil(res)
    assert.is_nil(werr)
    assert.is_true(again)

    -- test that return result
    sleep(0.51)
    res, werr, again = p:wait('nohang')
    assert.equal(res, {
        pid = pid,
        exit = 123,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

local function test_wait_untraced()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123 after sig continued
        assert(signal.kill(signal.SIGSTOP))
        os.exit(123)
    end
    local pid = p:pid()

    -- test that res.sigstop=SIGSTOP
    local res, werr, again = p:wait('untraced')
    assert.equal(res, {
        pid = pid,
        sigstop = signal.SIGSTOP,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

local function test_wait_continued()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit 123 after sig continued
        assert(signal.kill(signal.SIGSTOP))
        sleep(0.01)
        os.exit(123)
    end
    local pid = p:pid()
    sleep(0.01)

    -- test that res.sigcont=true
    local pp = assert(fork())
    if pp:is_child() then
        -- test that send SIGCONT signal after 100ms
        sleep(0.1)
        assert(signal.kill(signal.SIGCONT, pid))
        os.exit()
    end
    local res, werr, again = p:wait('continued')
    assert.equal(res, {
        pid = pid,
        sigcont = true,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

local function test_wait_sigterm()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit with sigterm after 100ms
        sleep(0.1)
        assert(signal.kill(signal.SIGTERM))
        os.exit(123)
    end
    local pid = p:pid()

    -- test that return again=true
    local res, werr, again = p:wait()
    assert.equal(res, {
        pid = pid,
        sigterm = signal.SIGTERM,
    })
    assert.is_nil(werr)
    assert.is_nil(again)
end

local function test_kill()
    local p = assert(fork())
    if p:is_child() then
        -- test that child process exit with sigterm after 100ms
        sleep(0.1)
        os.exit(123)
    end
    local pid = p:pid()

    -- test that return sigterm=SIGTERM
    local res, werr, again = p:kill()
    assert.equal(res, {
        pid = pid,
        sigterm = signal.SIGTERM,
    })
    assert.is_nil(werr)
    assert.is_nil(again)

    -- test that return ESRCH after exit
    res, werr, again = p:kill()
    assert.is_nil(res)
    assert.equal(werr.type, errno.ESRCH)
    assert.is_nil(again)

end

test_fork()
test_wait()
test_wait_nohang()
test_wait_untraced()
test_wait_continued()
test_wait_sigterm()
test_kill()
